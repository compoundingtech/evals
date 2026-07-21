#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# lib-harness.sh — shared eval-harness helpers. SOURCE this from a cell's
# spin.sh / configure-*-agent.sh so every eval pty session lives in a per-run,
# DECOUPLED PTY_ROOT and is torn down without ever polluting the operator's
# global pty namespace.
#
#   HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
#   . "$HERE/../../../bin/lib-harness.sh"        # from cells/<cell>/fixture/
#   CELL="$(basename "$(dirname "$HERE")")"      # cells/<cell>/fixture -> <cell>
#   stev_init "$CELL" "$SB"                       # once per run (idempotent)
#   export PTY_ROOT="$(stev_pty_root "$SB")"      # every session lands here
#   stev_arm_teardown "$SB"                       # crash / Ctrl-C safety
#
# THE PROBLEM this solves: the smalltalk BUS is isolated per run (ST_ROOT), but the
# pty session namespace is otherwise GLOBAL — shared with the operator's live
# agents. A cell that named its sessions with a bare id could orphan sessions in
# the operator's `pty ls` or CLOBBER a live session via a name collision.
#
# THE FIX — a per-run DECOUPLED PTY_ROOT (this retires the old collision-proof
# prefix + track_extra machinery, and the mid-launch-orphan class it carried):
#   1. stev_init mints a SHORT root `/tmp/stev-<runid>` (short by construction —
#      the 104-byte unix-socket-path limit forbids deep `<ST_ROOT>/pty` nesting).
#   2. A cell EXPORTS it: `export PTY_ROOT="$(stev_pty_root "$SB")"`. `st launch`
#      (and `pty up`, any worker a CoS stands up, the `st ding` sidecar) honors a
#      direct $PTY_ROOT verbatim (smalltalk #69) → EVERY session in the run lands
#      in this one physical partition. No prefix, no per-session registration:
#      nothing to miss, nothing that can reach another run or the operator.
#   3. stev_teardown kills every session in the run's PTY_ROOT + removes the root
#      + neuters every pty.toml the run wrote (→ .done) so pty gc can't resurrect
#      a finished agent. Idempotent.
#   4. stev_arm_teardown installs an EXIT/INT/TERM trap that tears down on
#      CRASH / Ctrl-C / early-exit; on a CLEAN spin it LEAVES the sessions up
#      (agents run async after spin) and prints the post-grade teardown command.
# ─────────────────────────────────────────────────────────────────────────────

# --- run identity -----------------------------------------------------------

# A short, collision-proof per-run id. uuidgen when available; else a shell PRNG.
stev_gen_runid() {
  if command -v uuidgen >/dev/null 2>&1; then
    uuidgen | tr 'A-Z' 'a-z' | tr -d '-' | cut -c1-6
  else
    printf '%06x' "$(( (RANDOM << 8 ^ RANDOM) & 0xffffff ))"
  fi
}

# stev_init <cell> <SB> : generate the per-run id ONCE and persist cell+runid+the
# decoupled PTY_ROOT so every script in the run (setup / configure×N / spin) reads
# the same values. Idempotent — safe to call from more than one script.
stev_init() {
  local cell="$1" sb="$2"
  [ -n "$cell" ] && [ -n "$sb" ] || { echo "stev_init: usage: stev_init <cell> <SB>" >&2; return 2; }
  mkdir -p "$sb/.stev"
  [ -s "$sb/.stev/cell" ]  || printf '%s\n' "$cell" > "$sb/.stev/cell"
  [ -s "$sb/.stev/runid" ] || printf '%s\n' "$(stev_gen_runid)" > "$sb/.stev/runid"
  # Mint a per-run SHORT, decoupled PTY_ROOT (`/tmp/stev-<runid>`). The 104-byte unix-socket path limit forbids
  # the deep `<ST_ROOT>/pty` nesting, so this is short by construction. Cells EXPORT it (see stev_pty_root) so
  # `st launch` honors it verbatim (needs st launch's direct-$PTY_ROOT support, smalltalk #69).
  [ -s "$sb/.stev/pty-root" ] || printf '/tmp/stev-%s\n' "$(cat "$sb/.stev/runid")" > "$sb/.stev/pty-root"
  mkdir -p "$(cat "$sb/.stev/pty-root")" 2>/dev/null || true
}

stev_cell()  { cat "$1/.stev/cell"  2>/dev/null; }
stev_runid() { cat "$1/.stev/runid" 2>/dev/null; }
# stev_pty_root <SB> : the run's decoupled short PTY_ROOT. Every cell does
#   export PTY_ROOT="$(stev_pty_root "$SB")"
# before launching so EVERY session (agent, st-launch worker, ding sidecar) lands in it — a physical partition
# from the operator's global pty daemon.
stev_pty_root() { cat "$1/.stev/pty-root" 2>/dev/null; }

# --- ding-mode toggle -------------------------------------------------------
# The WHOLE-SUITE --ding switch. Some hosts can't run MCP servers, so every cell
# must ALSO pass in the no-MCP `st launch … --ding` shape (agents coordinate over
# the `st` CLI + `st ding` inbox pokes instead of the `st` MCP channel). This makes
# that ONE switch, not a per-cell edit: every cell's configure-*-agent.sh consults
# these two helpers.
#
#   st launch claude $(stev_ding_flags) --identity … --unattended   # splice UNQUOTED
#
# The `st ding` sidecar the launch adds (`<id>-ding`) inherits the run's exported
# PTY_ROOT, so the root sweep tears it down — no per-session registration needed.
# Turn it on with `evals run <cell> --ding` or `EVAL_DING=1`.

# stev_ding_on : true (rc 0) iff ding-mode is enabled for this run.
stev_ding_on() {
  case "${EVAL_DING:-}" in
    1|true|TRUE|yes|YES|on|ON) return 0 ;;
    *) return 1 ;;
  esac
}

# stev_ding_flags : echo `--ding` when ding-mode is on, nothing otherwise. Splice
# UNQUOTED into an `st launch` line — off = empty = a normal MCP-mode launch
# (byte-identical to before the toggle existed, so MCP-mode never regresses); on
# = the no-MCP + `st ding` sidecar shape.
# LEGACY: kept only for reference. The suite launches via REAL convoy now (see stev_convoy_add) — convoy
# add is DING by default (no MCP), matching the ding-only reality, so this toggle is inverted below.
stev_ding_flags() { stev_ding_on && printf -- '--ding' || true; }

# --- convoy launch (replaces the removed `st launch`) -----------------------
# The suite spins agents via REAL convoy. `convoy add` is correct-by-construction: it writes DING-BUS.md +
# CLAUDE.md, the boot hooks (asyncRewake/PreCompact/StopFailure), pty.toml, installs the composed persona
# (--persona), starts the pty session AND a `st ding` wake sidecar — all on the ISOLATED network ($ST_ROOT,
# which spin.sh points at $SB/st-root). DING by default (no MCP), matching the ding-only reality.

# stev_mcp_on : true iff a cell FORCES MCP (EVAL_MCP=1) — the exception, for a cell that genuinely tests MCP
# (e.g. hook-integrity needs MCP on both legs). Default = ding (no MCP).
stev_mcp_on() { case "${EVAL_MCP:-}" in 1|true|TRUE|yes|YES|on|ON) return 0 ;; *) return 1 ;; esac; }

# stev_convoy_add <id> <dir> <mode> <persona> [harness] : DECLARE + LAUNCH ONE eval agent via REAL convoy
# on the isolated network ($ST_ROOT). convoy is DECLARATIVE (add=declare / render=materialize /
# up=reconcile): `convoy add` alone writes only the catalog agent file and launches NOTHING, so this
# helper follows it with `convoy up --once` (one-shot reconcile-and-exit) to actually spawn the session
# + ding sidecar. `up --once` ADOPTS already-live sessions, so calling this per-agent is idempotent —
# each add reconciles the whole host, later calls adopt the earlier agents instead of respawning them. Does NOT pre-trust the folder — convoy-core batch-pre-trusts every member's
# --dir before any boot (the CENTRAL fix for the multi-spawn workspace-trust race; see the body). Derives the
# convoy role from the permission mode (bypassPermissions → supervisor / spawn-capable; else → worker),
# and `convoy add`s it (ding by default; --mcp iff EVAL_MCP=1). ST_ROOT must be the isolated network
# (spin.sh exports it). `harness` (default claude; codex for the full-Codex cells) is emitted in the
# SPACE form `--harness codex` — NEVER `--harness=codex`, which convoy silently ignores → falls back to
# claude (a "thought it ran codex, actually ran claude" false-harness bug). convoy add --harness codex is
# correct-by-construction: it writes the codex rig (codex session + AGENTS.md from --persona + a `st ding`
# wake sidecar since Codex has no asyncRewake + ~/.codex/config.toml pre-trust).
stev_convoy_add() {
  local id="$1" d="$2" mode="$3" persona="$4" harness="${5:-claude}"
  case "$harness" in claude|codex) ;; *) echo "stev_convoy_add: harness must be claude|codex (got '$harness')" >&2; return 2 ;; esac
  local NET="${ST_ROOT:?stev_convoy_add: export ST_ROOT to the isolated convoy network first}"
  [ -f "$persona" ] || { echo "stev_convoy_add: missing composed persona $persona — compose it first" >&2; return 1; }
  local conv_role=worker; [ "$mode" = "bypassPermissions" ] && conv_role=supervisor
  # NO per-add workspace-trust write here (deliberate — the CENTRAL fix for the multi-spawn trust race).
  # convoy-core batch-pre-trusts every member's --dir BEFORE any session boots — covering bare `convoy add` —
  # so the harness must NOT also pre-trust: a per-add write lost-updates against sibling boots and RE-OPENS the
  # race (the clobbered agent silently stalls on the workspace-trust dialog and the grade flakes). If a cell
  # flakes on the trust dialog after the convoy-core fix, that's a convoy-core pre-trust GAP to FIX, not to
  # paper over here (integrity over convenience). Removed the old inline per-add pre-trust; see the
  # pretrust-multispawn-race sweep.
  # SPACE form only — never `--harness=$harness` (convoy silently ignores the equals form → falls back to claude).
  # NOTE: convoy derives the permission posture from the ROLE (worker/supervisor) and always launches the
  # session bypassPermissions; it does NOT take --permission-mode (convoy #30/#31 rejects it loudly). $mode is
  # kept only to pick conv_role above.
  if stev_mcp_on; then
    convoy add "$conv_role" --identity "$id" --network "$NET" --dir "$d" --persona "$persona" --harness "$harness" --mcp
  else
    convoy add "$conv_role" --identity "$id" --network "$NET" --dir "$d" --persona "$persona" --harness "$harness"
  fi
  # convoy add only DECLARES. Reconcile once to materialize the overlay + spawn this host's agents; --once
  # exits instead of daemonizing, and leaves the spawned sessions running (agents are decoupled from the
  # supervisor). Without this the whole live suite declares agents that never start — and every downstream
  # assertion then fails for a reason that looks like a product bug.
  convoy up --once "$NET" >/dev/null || { echo "stev_convoy_add: 'convoy up --once' failed for $id on $NET" >&2; return 1; }
  echo "launched $id  (convoy add $conv_role/$harness + up --once, $(stev_mcp_on && echo MCP || echo 'ding / no MCP'), net=$NET, --permission-mode $mode, persona=$persona)"
}

# stev_convoy_init <NET> : create a fresh isolated convoy network (idempotent — wipes any prior run's net).
# Also guards the pty socket-path length (unix sockets cap ~104 bytes; $NET/pty/silber.<id>.ding.sock must fit).
stev_convoy_init() {
  local NET="$1"
  [ "${#NET}" -le 70 ] || { echo "stev_convoy_init: NET path too long for the pty socket limit ($NET) — use a shorter EVAL_SANDBOX" >&2; return 2; }
  rm -rf "$NET"; convoy init "$NET" >/dev/null
}

# stev_convoy_teardown <NET> : tear the isolated network down (convoy down is the only path that kills
# sessions) + remove it. Idempotent.
stev_convoy_teardown() {
  local NET="$1"
  [ -n "$NET" ] || return 0
  convoy down "$NET" --force >/dev/null 2>&1 || true
  rm -rf "$NET" 2>/dev/null || true
}

# --- hermetic kick delivery -------------------------------------------------
# stev_seed_kick <NET> <recipient-id> <kick-file> [requester-override] : deliver a cell's ONE hermetic kick
# to a convoy-launched agent over the REAL isolated bus.
#
# WHY THIS EXISTS (the hollow-green bug it fixes): convoy runs smalltalk under $NET/smalltalk and
# HOST-PREFIXES every agent (e.g. hetz.<id>). The pre-convoy `$NET/<id>/inbox` file-drop therefore landed
# in a directory NOBODY watches → the kick never reached the agent, so the team spun GREEN (rc 0, agents
# boot) but idled on an empty inbox and did nothing. Every team-loop cell shared this bug.
#
# THE FIX: wait (bounded) for the recipient to register its bus dir under $NET/smalltalk, resolve the real
# host-prefixed id convoy assigned, and deliver the kick via `st message send` AS the requester. st writes
# the correct host-prefixed inbox AND notifies the recipient's `st ding` socket, so an already-booted agent
# is poked to drain it immediately (a raw file-drop at the right path is picked up too, but only on the
# next inbox poll). The kick file stays the single source of truth: its subject/priority/body are parsed
# and sent, and the SENDER defaults to the kick's own `from:` header (so the agent confirms back to the
# right requester) — pass a 4th arg only to override it. For a kick needing templating (e.g. a token),
# render it to a temp file first and pass that.
stev_seed_kick() {
  local net="$1" rid="$2" kick="$3" requester="${4:-}"
  [ -n "$net" ] && [ -n "$rid" ] && [ -n "$kick" ] \
    || { echo "stev_seed_kick: usage: stev_seed_kick <NET> <recipient-id> <kick-file> [requester-override]" >&2; return 2; }
  [ -f "$kick" ] || { echo "stev_seed_kick: no kick file at '$kick'" >&2; return 1; }
  # requester = explicit override, else the kick's own `from:` (single source of truth), else eval-runner
  [ -n "$requester" ] || requester="$(sed -n 's/^from:[[:space:]]*//p' "$kick" | head -1 | tr -d '"')"
  [ -n "$requester" ] || requester="eval-runner"
  local sm="$net/smalltalk" bus="" i=0
  # convoy creates the recipient's bus dir when the agent registers on boot; that can lag the launch.
  # `find` (not an `ls` glob) so a no-match returns rc 0 and never trips a caller's `set -e`.
  while [ "$i" -lt 90 ]; do
    bus="$(find "$sm" -maxdepth 1 -type d \( -name "*.$rid" -o -name "$rid" \) 2>/dev/null | head -1)"
    if [ -n "$bus" ]; then break; fi
    i=$((i + 1)); sleep 1
  done
  [ -n "$bus" ] || { echo "stev_seed_kick: '$rid' never registered a bus dir under $sm — did it boot?" >&2; return 1; }
  local id subj prio body
  id="$(basename "$bus")"                                   # the real host-prefixed id convoy assigned
  subj="$(sed -n 's/^subject:[[:space:]]*//p' "$kick" | head -1 | sed 's/^"//;s/"$//')"
  prio="$(sed -n 's/^priority:[[:space:]]*//p'  "$kick" | head -1)"
  body="$(awk 'seen>=2; /^---$/{seen++}' "$kick")"          # everything after the 2nd `---` (the body)
  [ -n "$body" ] || body="$(cat "$kick")"                   # a kick with no frontmatter → whole file is body
  ST_ROOT="$sm" ST_AGENT="$requester" st message send "$id" \
    --subject "${subj:-kick}" --priority "${prio:-normal}" -m "$body" >/dev/null \
    || { echo "stev_seed_kick: 'st message send' to $id failed" >&2; return 1; }
  echo "stev_seed_kick: delivered kick ($requester -> $id) over $sm"
}

# stev_kick_landed <NET> <recipient-id> [<from-id>] : rc 0 iff a message is present in the recipient's REAL
# (host-prefixed) bus inbox OR archive — a cheap "the kick reached the team" check, short of a full run.
# With <from-id>, require a message from that sender (host-prefix tolerant). Poll it a few times after spin.
stev_kick_landed() {
  local net="$1" rid="$2" from="${3:-}" sm bus
  sm="$net/smalltalk"
  bus="$(find "$sm" -maxdepth 1 -type d \( -name "*.$rid" -o -name "$rid" \) 2>/dev/null | head -1)"
  [ -n "$bus" ] || return 1
  if [ -n "$from" ]; then
    grep -qRE "^from:[[:space:]]*([a-z0-9][a-z0-9._-]*\.)?$from([[:space:]]|\$)" "$bus/inbox" "$bus/archive" 2>/dev/null
  else
    find "$bus/inbox" "$bus/archive" -name '*.md' 2>/dev/null | grep -q .
  fi
}

# --- teardown ---------------------------------------------------------------

# stev_teardown <SB> : remove EVERY pty session in this run's decoupled PTY_ROOT +
# neuter every pty.toml the run wrote. Idempotent; safe to call repeatedly.
stev_teardown() {
  local sb="$1"
  [ -s "$sb/.stev/runid" ] || { echo "stev_teardown: no run to tear down at $sb" >&2; return 0; }
  # Kill every session in the run's DECOUPLED PTY_ROOT, then remove the root. A physical partition ⇒ can't miss a
  # session, can't touch another run or the operator's live agents.
  local pr; pr="$(stev_pty_root "$sb")"
  if [ -n "$pr" ] && [ -d "$pr" ]; then
    pty --root "$pr" ls 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g' | grep -oE '\([a-z0-9]+\)' | tr -d '()' \
      | while read -r sid; do [ -n "$sid" ] && { pty --root "$pr" kill "$sid" >/dev/null 2>&1 || true; }; done
    pty --root "$pr" gc >/dev/null 2>&1 || true
    rm -rf "$pr" 2>/dev/null || true
  fi
  # Neuter pty.toml so pty gc cannot resurrect a finished agent as a zombie.
  find "$sb" -name pty.toml -type f 2>/dev/null | while read -r t; do
    mv "$t" "$t.done" 2>/dev/null || true
  done
  echo "stev: torn down run '$(stev_cell "$sb")/$(stev_runid "$sb")' (PTY_ROOT $pr)" >&2
}

# stev_arm_teardown <SB> : guaranteed cleanup on CRASH / Ctrl-C / early-exit,
# WITHOUT killing a cleanly-spun team (agents run async after spin returns). Call
# once, early in spin.sh, right after stev_init.
stev_arm_teardown() {
  export STEV_SB="$1"
  trap '_stev_on_exit' EXIT
  trap 'exit 130' INT
  trap 'exit 143' TERM
}
_stev_on_exit() {
  local rc=$?
  local sb="${STEV_SB:-.}"
  if [ "$rc" != "0" ]; then
    echo "== stev: spin exited rc=$rc — tearing down this run's pty sessions ==" >&2
    stev_teardown "$sb"
  else
    echo "== stev: sessions up in PTY_ROOT '$(stev_pty_root "$sb")'. After grading, tear down with:" >&2
    echo "     bin/evals teardown \"$sb\"" >&2
  fi
}
