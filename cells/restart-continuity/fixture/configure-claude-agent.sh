#!/usr/bin/env bash
# Launch one Restart-continuity Claude eval agent via REAL convoy (`convoy add`, ding-default). Normal call
# = `stev_convoy_add` (pre-trust + convoy add on the ISOLATED net $ST_ROOT, exported by spin.sh).
#
# THE ONE EXTRA THING THIS CELL NEEDS — a COLD RESTART of the worker (RC_RESTART): `pty restart` SIGTERMs +
# respawns the agent session from convoy's stored pty.toml command — which carries NO `--resume`, so the
# respawn is a COLD boot (fresh transcript). The `st ding` sidecar + the agent's st dir (inbox) stay up, so
# durable state (ledger commits + inbox) persists and the agent must RESUME. Restarts ONLY the claude
# session (key `silber.<id>-claude`), never the whole net — the live network is untouched.
#   ./configure-claude-agent.sh <sup|dev> [SANDBOX]                 # normal launch
#   RC_RESTART=1 ./configure-claude-agent.sh dev [SANDBOX]          # COLD relaunch of the worker
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/../../../bin/lib-harness.sh"
role="$1"; SB="${2:-${EVAL_SANDBOX:-./.sandbox}/restart-continuity}"
RC_RESTART="${RC_RESTART:-}"
NET="${ST_ROOT:?spin.sh must convoy-init + export ST_ROOT to the isolated net ($SB/st-root) first}"

case "$role" in
  sup) id="rc-sup"; d="$SB/sup";    mode="bypassPermissions" ;;   # coordinate-only, spawn-capable
  dev) id="rc-dev"; d="$SB/ledger"; mode="auto" ;;                # owns the repo; no child agents
  *) echo "role must be sup|dev" >&2; exit 1 ;;
esac

if [ -n "$RC_RESTART" ]; then
  echo "== COLD RESTART ($id, gen $RC_RESTART): pty restart the agent session (SIGTERM+respawn from convoy's pty.toml — no --resume => cold boot; inbox + ding preserved) =="
  rm -f "$d/.claude-session-id"   # belt-and-suspenders cold boot (convoy's launch command carries no --resume anyway)
  pty --root "$NET/pty" restart -y "silber.$id-claude"
  echo "launched $id  (COLD-RESTART gen $RC_RESTART: fresh transcript, same isolated bus=$NET, cwd=$d)"
  exit 0
fi

stev_convoy_add "$id" "$d" "$mode" "$SB/personas-local/$id.md"
