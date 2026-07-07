#!/usr/bin/env bash
# Launch one signal-rename Claude eval agent via the REAL `st launch` (not a homegrown config writer).
# `st launch` writes .mcp.json (server `st`), the boot hooks (asyncRewake/PreCompact/StopFailure), the
# session-id, pty.toml, installs the composed persona (--persona), and starts the pty session. We add the two
# things st launch does NOT do for an eval:
#   1. ISOLATION: the isolated coordination bus reaches the agent by ENV INHERITANCE — spin.sh exports
#      ST_ROOT/COORD_ROOT before calling this, so st launch -> pty session -> claude -> the `st` MCP server all
#      inherit the isolated root (the agent registers on $ST_ROOT; the live bus is untouched).
#   2. ZERO-ORPHAN TEARDOWN: --session-name "$(stev_prefix ...)" makes the pty session name collision-proof
#      (`<id>-stev-<cell>-<runid>-<id>`, never a bare `<id>-claude`); stev_track_extra registers that EXACT name
#      so `st-evals teardown` removes it.
# Each agent's cwd = the repo it OWNS (sup -> signal-config; base -> signal; relay -> signal-relay; hub -> signal-hub).
# Permission POSTURE: SUPERVISOR = bypassPermissions (integration + git + runs suites across the stack); product
# workers = auto.
#   ./configure-claude-agent.sh <sup|base|relay|hub> [SANDBOX]   # ST_ROOT must be exported (spin.sh does this)
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/../../../bin/lib-harness.sh"
role="$1"; SB="${2:-${EVAL_SANDBOX:-./.sandbox}/signal-rename}"
ROOT="${ST_ROOT:?spin.sh must export ST_ROOT to the isolated bus root ($SB/st-root) before launching}"
stev_init "$(basename "$(dirname "$HERE")")" "$SB"   # collision-proof pty prefix; idempotent (standalone-safe)

case "$role" in
  sup)   id="sig-sup";   d="$SB/sup";   mode="bypassPermissions" ;;   # integration lead; owns app.toml
  base)  id="sig-base";  d="$SB/base";  mode="auto" ;;                # owns the base package
  relay) id="sig-relay"; d="$SB/relay"; mode="auto" ;;                # owns signal-relay (the trap repo)
  hub)   id="sig-hub";   d="$SB/hub";   mode="auto" ;;                # owns signal-hub (the scheme)
  *) echo "role must be sup|base|relay|hub" >&2; exit 1 ;;
esac
persona="$SB/personas-local/$id.md"
[ -f "$persona" ] || { echo "missing composed persona $persona — run compose-persona.sh $role first" >&2; exit 1; }
# stev-retirement: NO collision-proof prefix, NO track_extra. The run's decoupled short PTY_ROOT (exported by
# spin.sh, honored verbatim by st launch #69) physically isolates every session — the agent AND the `st ding`
# sidecar — from the operator's global pty daemon, so a plain session name is fine and teardown just kills
# everything in the run's PTY_ROOT.

# Pre-create the FULL coord dir on the ISOLATED bus so the boot ritual doesn't rabbit-hole for its own folder.
mkdir -p "$ROOT/$id/inbox" "$ROOT/$id/archive"; printf 'available\n' > "$ROOT/$id/status"

# Pre-trust the folder for Claude Code (skip the workspace-trust gate). --unattended also auto-pokes startup
# gates, but pre-trust is deterministic + cheap — keep both.
python3 - "$d" <<'PY'
import json,os,sys
p=os.path.expanduser("~/.claude.json")
d=json.load(open(p)) if os.path.exists(p) else {}
e=d.setdefault("projects",{}).setdefault(sys.argv[1],{})
e["hasTrustDialogAccepted"]=True; e["hasCompletedProjectOnboarding"]=True
json.dump(d,open(p,"w"),indent=2)
PY

# (stev-retirement: no stev_track_extra — every session, incl. the ding sidecar, is in the run's PTY_ROOT and
#  is torn down by killing that root. The mid-launch-orphan class the pre-launch registration guarded against
#  is gone by construction — a kill mid-launch still leaves the session inside the run's PTY_ROOT.)

# Launch via the real st launch; it inherits ST_ROOT/COORD_ROOT from this process (exported by spin.sh) ->
# the agent binds the ISOLATED bus. --unattended bakes the startup auto-poker; --session-name is collision-proof.
( cd "$d" && st launch claude $(stev_ding_flags) \
    --identity "$id" \
    --session-name run \
    --permission-mode "$mode" \
    --persona "$persona" \
    --unattended )

echo "launched $id  (pty root=${PTY_ROOT:-?}, session=$id-run$(stev_ding_on && echo " + $id-ding sidecar"), --permission-mode $mode, isolated bus=$ROOT, persona=$persona, asyncRewake)"
