#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# Launch one Restart-continuity Claude eval agent via the REAL `st launch`. Same
# retrofit pattern as the other cells (see cells/ghost-bug/fixture): st launch
# writes .mcp.json (server `st`), the boot hooks, the session-id, pty.toml, and
# installs the composed persona; we add ISOLATION (RISK 2 — the isolated bus
# reaches the agent by ENV INHERITANCE: spin.sh exports ST_ROOT/COORD_ROOT, which
# st launch bakes into the generated [sessions.*.env]) and ZERO-ORPHAN TEARDOWN
# (RISK 1 — a collision-proof --session-name + stev_track_extra of the EXACT name).
#
# THE ONE EXTRA THING THIS CELL NEEDS — a COLD RESTART of the worker (RC_RESTART):
#   st launch REUSES an existing .claude-session-id (→ `--resume <sid>` = warm) and
#   SKIPS an existing pty.toml. So to relaunch the SAME identity as a FRESH cold
#   boot (no prior transcript) we, before relaunching:
#     1. pty kill + pty rm the worker's current session,
#     2. rm .claude-session-id  → st launch mints a fresh UUID → fresh transcript,
#     3. rm pty.toml(.done)      → st launch writes a fresh pty.toml,
#   then relaunch with a NEW --session-name (`<pfx>-r<n>`) so the pty key differs
#   from the killed one, and stev_track_extra the new exact name. Identity, persona,
#   repo, and bus are unchanged — same git author across the restart, so isolation
#   attribution still holds. This is invoked by restart-injector.sh.
#
#   ./configure-claude-agent.sh <sup|dev> [SANDBOX]      # normal launch (ST_ROOT must be exported)
#   RC_RESTART=1 ./configure-claude-agent.sh dev [SANDBOX]  # COLD relaunch of the worker
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/../../../bin/lib-harness.sh"
role="$1"; SB="${2:-${EVAL_SANDBOX:-./.sandbox}/restart-continuity}"
ROOT="${ST_ROOT:?spin.sh must export ST_ROOT to the isolated bus root ($SB/st-root) before launching}"
RC_RESTART="${RC_RESTART:-}"
stev_init "$(basename "$(dirname "$HERE")")" "$SB"   # collision-proof pty prefix; idempotent (standalone-safe)

case "$role" in
  sup) id="rc-sup"; d="$SB/sup";    mode="bypassPermissions" ;;   # coordinate-only, spawn-capable
  dev) id="rc-dev"; d="$SB/ledger"; mode="auto" ;;                # owns the repo; no child agents
  *) echo "role must be sup|dev" >&2; exit 1 ;;
esac
persona="$SB/personas-local/$id.md"
[ -f "$persona" ] || { echo "missing composed persona $persona — run compose-persona.sh $role first" >&2; exit 1; }
# stev-retirement: NO collision-proof prefix, NO track_extra. The run's decoupled short PTY_ROOT (exported by
# spin.sh AND by restart-injector.sh, honored verbatim by st launch #69) physically isolates every session from
# the operator's global pty daemon; teardown just kills everything in the run's PTY_ROOT.

# On a cold RESTART, tear down the old worker session (in the run's PTY_ROOT) + wipe the cold-boot state so the
# relaunch is a genuine fresh boot with a distinct session name (`run-r<n>`, distinct from the killed `run`).
if [ -n "$RC_RESTART" ]; then
  pr="$(stev_pty_root "$SB")"; oldsess="$id-run"
  echo "== COLD RESTART ($id, gen $RC_RESTART): killing $oldsess in PTY_ROOT $pr + wiping transcript/pty.toml =="
  pty --root "$pr" kill "$oldsess" >/dev/null 2>&1 || true
  pty --root "$pr" rm   "$oldsess" >/dev/null 2>&1 || true
  rm -f "$d/.claude-session-id" "$d/pty.toml" "$d/pty.toml.done"
  sname="run-r$RC_RESTART"          # new pty session-name → key <id>-run-r<n> (distinct from the killed <id>-run)
else
  sname="run"
fi

# Pre-create the FULL coord dir on the ISOLATED bus so the boot ritual doesn't rabbit-hole. On a
# restart this is idempotent (dir already exists; the worker's inbox/archive carry the durable bus record).
mkdir -p "$ROOT/$id/inbox" "$ROOT/$id/archive"; [ -f "$ROOT/$id/status" ] || printf 'available\n' > "$ROOT/$id/status"

# Pre-trust the folder for Claude Code (skip the workspace-trust gate). Belt-and-suspenders with --unattended.
python3 - "$d" <<'PY'
import json,os,sys
p=os.path.expanduser("~/.claude.json")
d=json.load(open(p)) if os.path.exists(p) else {}
e=d.setdefault("projects",{}).setdefault(sys.argv[1],{})
e["hasTrustDialogAccepted"]=True; e["hasCompletedProjectOnboarding"]=True
json.dump(d,open(p,"w"),indent=2)
PY

# Launch via the real st launch. It inherits ST_ROOT/COORD_ROOT from this process's env (exported by
# spin.sh) → the agent binds the ISOLATED bus. --unattended bakes the startup auto-poker.
( cd "$d" && st launch claude $(stev_ding_flags) \
    --identity "$id" \
    --session-name "$sname" \
    --permission-mode "$mode" \
    --persona "$persona" \
    --unattended )

# (stev-retirement: no stev_track_extra — every session (each restart generation) + the ding sidecar live in
#  the run's PTY_ROOT and are torn down by killing that root. The mid-launch-orphan class is gone by construction.)

echo "launched $id  (pty root=${PTY_ROOT:-?}, session=$id-$sname$(stev_ding_on && echo " + $id-ding sidecar"), --permission-mode $mode, isolated bus=$ROOT, persona=$persona${RC_RESTART:+, COLD-RESTART gen $RC_RESTART})"
