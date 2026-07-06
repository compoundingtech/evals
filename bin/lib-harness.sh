#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# lib-harness.sh — shared eval-harness helpers. SOURCE this from a cell's
# spin.sh / configure-*-agent.sh so every eval pty session lives under a
# COLLISION-PROOF, per-run prefix and is torn down without ever polluting the
# operator's global pty namespace.
#
#   HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
#   . "$HERE/../../../bin/lib-harness.sh"        # from cells/<cell>/fixture/
#   CELL="$(basename "$(dirname "$HERE")")"      # cells/<cell>/fixture -> <cell>
#   stev_init "$CELL" "$SB"                       # once per run (idempotent)
#
# THE PROBLEM this solves: the coord BUS is isolated per run (ST_ROOT), but the
# pty session namespace is GLOBAL — shared with the operator's live agents
# (each named for its harness). A cell that names its sessions with a bare
# generic id (`sup`/`fix`/`rev` -> `<id>-<harness>`…) can (a) leave orphan sessions
# in the operator's `pty ls`, and (b) CLOBBER a live session via `pty up` on a
# colliding name. Both are real: this library removes both by construction.
#
# THE FIX:
#   1. stev_prefix <SB> <id>  ->  "stev-<cell>-<runid>-<id>"  (the pty.toml
#      `prefix` value). `stev-` can never collide with a live session; <runid>
#      disambiguates concurrent runs of the same cell; <id> disambiguates agents
#      within a run. Use it EVERYWHERE a cell used a bare `$id` prefix.
#   2. stev_teardown <SB>  ->  pty kill + pty rm EVERY session under this run's
#      unique prefix (prefix-keyed, so it can't miss one even if a cell forgot to
#      register a session), and neuter every pty.toml the run wrote (-> .done) so
#      pty gc can't resurrect a finished agent. Idempotent.
#   3. stev_arm_teardown <SB>  ->  install an EXIT/INT/TERM trap that runs
#      stev_teardown on CRASH / Ctrl-C / early-exit (nonzero rc). On a CLEAN spin
#      it deliberately LEAVES the sessions up (the agents run async after spin —
#      a naive teardown-on-clean-exit would kill the team we just launched) and
#      prints the exact post-grade teardown command.
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

# stev_init <cell> <SB> : generate the per-run id ONCE and persist cell+runid so
# every script in the run (setup / configure×N / spin) reads the same values.
# Idempotent — safe to call from more than one script.
stev_init() {
  local cell="$1" sb="$2"
  [ -n "$cell" ] && [ -n "$sb" ] || { echo "stev_init: usage: stev_init <cell> <SB>" >&2; return 2; }
  mkdir -p "$sb/.stev"
  [ -s "$sb/.stev/cell" ]  || printf '%s\n' "$cell" > "$sb/.stev/cell"
  [ -s "$sb/.stev/runid" ] || printf '%s\n' "$(stev_gen_runid)" > "$sb/.stev/runid"
  # stev-retirement: mint a per-run SHORT, decoupled PTY_ROOT (`/tmp/stev-<runid>`). The 104-byte unix-socket
  # path limit forbids the deep `<ST_ROOT>/pty` nesting, so this is short by construction. A cell that has cut
  # over EXPORTS this (see stev_pty_root) so `st launch` honors it verbatim (needs st launch's direct-$PTY_ROOT
  # support, smalltalk #69). Minting it here is harmless to cells not yet cut over — they simply don't export it.
  [ -s "$sb/.stev/pty-root" ] || printf '/tmp/stev-%s\n' "$(cat "$sb/.stev/runid")" > "$sb/.stev/pty-root"
  mkdir -p "$(cat "$sb/.stev/pty-root")" 2>/dev/null || true
}

stev_cell()  { cat "$1/.stev/cell"  2>/dev/null; }
stev_runid() { cat "$1/.stev/runid" 2>/dev/null; }
# stev_pty_root <SB> : the run's decoupled short PTY_ROOT. A cut-over cell does
#   export PTY_ROOT="$(stev_pty_root "$SB")"
# before launching so EVERY session (agent, st-launch worker, ding sidecar) lands in it — a physical partition
# from the operator's global pty daemon. Retires the collision-proof prefix + track_extra machinery.
stev_pty_root() { cat "$1/.stev/pty-root" 2>/dev/null; }

# stev_prefix <SB> <id> : the collision-proof pty prefix for one agent. Requires
# stev_init to have run for this SB.
stev_prefix() {
  local sb="$1" id="$2" cell rid
  cell="$(stev_cell "$sb")"; rid="$(stev_runid "$sb")"
  if [ -z "$cell" ] || [ -z "$rid" ]; then
    echo "stev_prefix: run not initialised — call stev_init <cell> <SB> first (SB=$sb)" >&2
    return 1
  fi
  printf 'stev-%s-%s-%s' "$cell" "$rid" "$id"
}

# stev_run_prefix <SB> : the shared "stev-<cell>-<runid>-" stem every session in
# this run starts with — the key teardown greps on.
stev_run_prefix() { printf 'stev-%s-%s-' "$(stev_cell "$1")" "$(stev_runid "$1")"; }

# stev_track_extra <SB> <session-name> : register a session that is NOT under our
# prefix so teardown removes it too. Needed for sessions a cell does not name
# itself — e.g. a worker a CoS stands up via `st launch`, which names the pty
# session `<identity>-<harness>` (prefix = identity), outside the fixture's reach.
# Idempotent per name.
stev_track_extra() {
  local sb="$1" name="$2"
  [ -n "$name" ] || return 0
  mkdir -p "$sb/.stev"
  grep -qxF "$name" "$sb/.stev/extra" 2>/dev/null || printf '%s\n' "$name" >> "$sb/.stev/extra"
}

# --- ding-mode toggle -------------------------------------------------------
# The WHOLE-SUITE --ding switch. Some hosts can't run MCP servers, so every cell
# must ALSO pass in the no-MCP `st launch … --ding` shape (agents coordinate over
# the `st` CLI + `st ding` inbox pokes instead of the `st` MCP channel). This makes
# that ONE switch, not a per-cell edit each: every cell's configure-*-agent.sh
# consults these two helpers.
#
#   st launch claude $(stev_ding_flags) --identity … --unattended   # splice UNQUOTED
#   stev_ding_on && stev_track_extra "$SB" "$id-ding"               # sidecar teardown
#
# Turn it on with `st-evals run <cell> --ding` or `ST_EVAL_DING=1`.

# stev_ding_on : true (rc 0) iff ding-mode is enabled for this run.
stev_ding_on() {
  case "${ST_EVAL_DING:-}" in
    1|true|TRUE|yes|YES|on|ON) return 0 ;;
    *) return 1 ;;
  esac
}

# stev_ding_flags : echo `--ding` when ding-mode is on, nothing otherwise. Splice
# UNQUOTED into an `st launch` line — off = empty = a normal MCP-mode launch
# (byte-identical to before the toggle existed, so MCP-mode never regresses); on
# = the no-MCP + `st ding` sidecar shape. LOAD-BEARING companion: under --ding the
# launch adds an `st ding` sidecar named `<id>-ding` (outside our stev prefix), so
# the caller MUST `stev_ding_on && stev_track_extra "$SB" "$id-ding"` or the sidecar
# orphans at teardown.
stev_ding_flags() { stev_ding_on && printf -- '--ding' || true; }

# --- teardown ---------------------------------------------------------------

# stev_teardown <SB> : remove EVERY pty session under this run's unique prefix +
# neuter every pty.toml the run wrote. Idempotent; safe to call repeatedly.
stev_teardown() {
  local sb="$1" stem
  [ -s "$sb/.stev/runid" ] || { echo "stev_teardown: no run to tear down at $sb" >&2; return 0; }
  stem="$(stev_run_prefix "$sb")"
  # stev-retirement: if this run used a DECOUPLED PTY_ROOT (a cut-over cell exported it), kill every session in
  # it and remove the root. Physical partition ⇒ can't miss a session, can't touch another run or the operator —
  # this retires the prefix-grep + track_extra dance (and the mid-launch-orphan class it had). No-op for cells
  # not yet cut over (their pty-root is minted-but-unused/empty; rm of an empty dir is harmless).
  local pr; pr="$(stev_pty_root "$sb")"
  if [ -n "$pr" ] && [ -d "$pr" ]; then
    pty --root "$pr" ls 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g' | grep -oE '\([a-z0-9]+\)' | tr -d '()' \
      | while read -r sid; do [ -n "$sid" ] && { pty --root "$pr" kill "$sid" >/dev/null 2>&1 || true; }; done
    pty --root "$pr" gc >/dev/null 2>&1 || true
    rm -rf "$pr" 2>/dev/null || true
  fi
  # LEGACY (cells not yet cut over): `pty ls` carries ANSI colour; strip it, then pull every session name under
  # our unique stem. Prefix-keyed so we never touch a live or other-run session.
  pty ls 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g' \
    | grep -oE "${stem}[A-Za-z0-9_-]*" | sort -u \
    | while read -r s; do
        pty kill "$s" >/dev/null 2>&1 || true
        pty rm   "$s" >/dev/null 2>&1 || true
      done
  # Extra externally-named sessions (e.g. an st-launch worker named `<identity>-claude`,
  # outside our prefix) registered via stev_track_extra.
  if [ -s "$sb/.stev/extra" ]; then
    while read -r s; do
      [ -n "$s" ] || continue
      pty kill "$s" >/dev/null 2>&1 || true
      pty rm   "$s" >/dev/null 2>&1 || true
    done < "$sb/.stev/extra"
  fi
  # Neuter pty.toml so pty gc cannot resurrect a finished agent as a zombie.
  find "$sb" -name pty.toml -type f 2>/dev/null | while read -r t; do
    mv "$t" "$t.done" 2>/dev/null || true
  done
  # A just-killed session lingers briefly as an `exited` record in `pty ls`; sweep those so teardown
  # leaves an instantly-clean list. `pty gc` only removes EXITED sessions — running agents (live or
  # other eval runs) are untouched — and our sessions are tags=role=agent (not permanent), so gc
  # removes rather than resurrects (pty.toml already neutered above as belt-and-suspenders).
  pty gc >/dev/null 2>&1 || true
  echo "stev: torn down run '$(stev_cell "$sb")/$(stev_runid "$sb")' (prefix ${stem}*)" >&2
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
    echo "== stev: sessions up under prefix '$(stev_run_prefix "$sb")*'. After grading, tear down with:" >&2
    echo "     bin/st-evals teardown \"$sb\"" >&2
  fi
}
