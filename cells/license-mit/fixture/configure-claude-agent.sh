#!/usr/bin/env bash
# Launch one license-mit Claude eval agent (sup|worker) via the REAL `st launch`. st launch writes
# .mcp.json (server `st`), .claude/settings.local.json (asyncRewake/PreCompact/StopFailure hooks,
# enableAllProjectMcpServers, enabledMcpjsonServers:["st"]), the session-id, pty.toml, installs the
# composed persona (--persona -> PERSONA.md + @PERSONA.md), and starts the pty session. We add the two
# eval-only things: ISOLATION (spin.sh exports ST_ROOT -> st launch bakes/inherits it -> agent binds the
# isolated bus) and ZERO-ORPHAN teardown (--session-name "$(stev_prefix)" -> collision-proof pty name;
# stev_track_extra the EXACT name). Plus deterministic startup hygiene (isolated coord dir + folder pre-trust).
# Posture mirrors the walked ghost-bug reference: SUPERVISOR = bypassPermissions, WORKER = auto.
#   ./configure-claude-agent.sh <sup|worker> [SANDBOX]   # ST_ROOT must be exported (spin.sh does this)
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/../../../bin/lib-harness.sh"
role="$1"; SB="${2:-${EVAL_SANDBOX:-./.sandbox}/license-mixed}"
ROOT="${ST_ROOT:?spin.sh must export ST_ROOT to the isolated bus root ($SB/st-root) before launching}"
SUP_ID="${SUP_ID:-mix-sup}"; WORKER_ID="${WORKER_ID:-mix-worker}"
stev_init "$(basename "$(dirname "$HERE")")" "$SB"   # collision-proof pty prefix; idempotent (standalone-safe)

case "$role" in
  sup)    id="$SUP_ID";    d="$SB/sup";    mode="bypassPermissions" ;;   # coordinate-only
  worker) id="$WORKER_ID"; d="$SB/worker"; mode="auto" ;;                # owns the widget repo
  *) echo "role must be sup|worker" >&2; exit 1 ;;
esac
persona="$SB/personas-local/$id.md"
[ -f "$persona" ] || { echo "missing composed persona $persona — run compose-persona.sh $role claude first" >&2; exit 1; }
# stev-retirement: NO collision-proof prefix, NO track_extra. The run's decoupled short PTY_ROOT (exported by
# spin.sh, honored verbatim by st launch #69) physically isolates every session — the agent AND the `st ding`
# sidecar — from the operator's global pty daemon, so a plain session name is fine and teardown just kills
# everything in the run's PTY_ROOT.

# Pre-create the FULL coord dir on the ISOLATED bus so the boot ritual doesn't rabbit-hole.
mkdir -p "$ROOT/$id/inbox" "$ROOT/$id/archive"; printf 'available\n' > "$ROOT/$id/status"

# Pre-trust the folder (deterministic; --unattended also auto-pokes the startup gates).
python3 - "$d" <<'PY'
import json,os,sys
p=os.path.expanduser("~/.claude.json")
d=json.load(open(p)) if os.path.exists(p) else {}
e=d.setdefault("projects",{}).setdefault(sys.argv[1],{})
e["hasTrustDialogAccepted"]=True; e["hasCompletedProjectOnboarding"]=True
json.dump(d,open(p,"w"),indent=2)
PY

# Launch via the real st launch. It inherits ST_ROOT/COORD_ROOT from this process (exported by spin.sh)
# and (post-#52) bakes ST_ROOT into the generated pty.toml env -> the agent binds the ISOLATED bus.
( cd "$d" && st launch claude $(stev_ding_flags) \
    --identity "$id" \
    --session-name run \
    --permission-mode "$mode" \
    --persona "$persona" \
    --unattended )

# (stev-retirement: no stev_track_extra — every session, incl. the ding sidecar, is in the run's PTY_ROOT and
#  is torn down by killing that root. The mid-launch-orphan class is gone by construction.)

echo "launched $id  (pty root=${PTY_ROOT:-?}, session=$id-run$(stev_ding_on && echo " + $id-ding sidecar"), --permission-mode $mode, isolated bus=$ROOT, persona=$persona, asyncRewake)"
