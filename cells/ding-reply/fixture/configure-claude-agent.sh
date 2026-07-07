#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# Launch the ding-reply agent via the REAL `st launch claude --ding`: NO MCP (.mcp.json skipped), channel OFF,
# an `st ding` sidecar for inbox delivery, Claude hooks still generated. The agent joins the network via the
# `st` CLI + ding pokes — the no-MCP shape (the MCP-less config). Same isolation + zero-orphan discipline as the
# other cells: spin.sh exports ST_ROOT (isolated bus) + the run's decoupled PTY_ROOT (st launch honors it #69,
# so the agent session AND the `st ding` sidecar both land in the run root; teardown removes the whole root).
#   ./configure-claude-agent.sh [SANDBOX]   # ST_ROOT must be exported (spin.sh does this)
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/../../../bin/lib-harness.sh"
SB="${1:-${EVAL_SANDBOX:-./.sandbox}/ding-reply}"
ROOT="${ST_ROOT:?spin.sh must export ST_ROOT to the isolated bus root ($SB/st-root) before launching}"
stev_init "$(basename "$(dirname "$HERE")")" "$SB"   # mint the run's decoupled PTY_ROOT (short, per-run); idempotent
id="dr-agent"; d="$SB/work"
persona="$SB/personas-local/$id.md"
[ -f "$persona" ] || { echo "missing composed persona $persona — run compose-persona.sh first" >&2; exit 1; }

# Pre-create the FULL st dir on the ISOLATED bus (inbox+archive+status) — the ding sidecar watches inbox/, and
# the agent's `st` CLI ops (incl. the reply) resolve against it.
mkdir -p "$ROOT/$id/inbox" "$ROOT/$id/archive"; printf 'available\n' > "$ROOT/$id/status"

# Pre-trust the folder for Claude Code (skip the workspace-trust gate). Belt-and-suspenders with --unattended.
python3 - "$d" <<'PY'
import json,os,sys
p=os.path.expanduser("~/.claude.json")
d=json.load(open(p)) if os.path.exists(p) else {}
e=d.setdefault("projects",{}).setdefault(sys.argv[1],{})
e["hasTrustDialogAccepted"]=True; e["hasCompletedProjectOnboarding"]=True
json.dump(d,open(p,"w"),indent=2)
PY

# Launch via the real `st launch claude --ding`: no MCP, ding sidecar, hooks still generated. Inherits ST_ROOT
# + PTY_ROOT from this process (exported by spin.sh) -> agent + ding bind the ISOLATED bus + land in the run root.
( cd "$d" && st launch claude --ding \
    --identity "$id" \
    --session-name run \
    --permission-mode auto \
    --persona "$persona" \
    --unattended )

echo "launched $id  (DING MODE: no MCP; agent session=$id-run + ding sidecar=$id-ding; isolated bus=$ROOT, cwd=$d, persona=$persona)"
