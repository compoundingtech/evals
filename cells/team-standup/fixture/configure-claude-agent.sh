#!/usr/bin/env bash
# Launch the TEAM-STANDUP CoS via the REAL `st launch` (not a homegrown config writer) — the SAME command
# a human runs to onboard a chief-of-staff (onboarding.md documents `st launch claude --identity cos …`),
# so the eval dogfoods the whole launch surface. ONLY the CoS is launched here; the CoS stands up
# taskflow-dev ITSELF via `st launch` during the run (that IS the P5 test — untouched).
# `st launch` writes .mcp.json (server `st`), .claude/settings.local.json (asyncRewake + PreCompact +
# StopFailure hooks, enableAllProjectMcpServers, enabledMcpjsonServers:["st"]), the session-id, pty.toml,
# installs the composed persona (--persona -> PERSONA.md + @PERSONA.md), and starts the pty session.
# We add the two eval-only concerns st launch leaves to the operator:
#   1. ISOLATION (RISK 2): the isolated bus reaches the CoS by ENV INHERITANCE — spin.sh exports
#      ST_ROOT/COORD_ROOT before calling this, so st launch -> pty session -> claude -> the `st` MCP server
#      inherit the isolated root (and post-#52 st also bakes ST_ROOT into the generated session env).
#   2. ZERO-ORPHAN + NO-CLOBBER (RISK 1): --session-name "$(stev_prefix ...)" makes the pty session name
#      collision-proof (`cos-stev-team-standup-<runid>-cos`, carries the runid) so it can NEVER clobber a
#      live `cos` pty session; we register that EXACT name via stev_track_extra so teardown is zero-orphan.
# Posture: CoS = bypassPermissions (spawn-capable — it shells `st launch` + `pty up` to stand up the worker).
#   ./configure-claude-agent.sh [SANDBOX]   # ST_ROOT must be exported (spin.sh does this)
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/../../../bin/lib-harness.sh"
SB="${1:-${EVAL_SANDBOX:-./.sandbox}/team-standup}"
ROOT="${ST_ROOT:?spin.sh must export ST_ROOT to the isolated bus root ($SB/st-root) before launching}"
stev_init "$(basename "$(dirname "$HERE")")" "$SB"   # collision-proof pty prefix; idempotent (standalone-safe)

id="cos"; d="$SB/cos"; mode="bypassPermissions"      # coordinate-only, spawn-capable; owns NO repo
persona="$SB/personas-local/$id.md"
[ -f "$persona" ] || { echo "missing composed persona $persona — run compose-persona.sh cos first" >&2; exit 1; }
pfx="$(stev_prefix "$SB" "$id")"     # stev-team-standup-<runid>-cos
sess="$id-$pfx"                       # st launch names the pty session <identity>-<session-name> = cos-<pfx>

# Pre-create the FULL coord dir on the ISOLATED bus so the boot ritual doesn't rabbit-hole.
mkdir -p "$ROOT/$id/inbox" "$ROOT/$id/archive"; printf 'available\n' > "$ROOT/$id/status"

# Pre-trust the CoS folder for Claude Code (skip the workspace-trust gate). --unattended also auto-pokes
# the startup gates, but pre-trust is deterministic and cheap — keep both.
python3 - "$d" <<'PY'
import json,os,sys
p=os.path.expanduser("~/.claude.json")
d=json.load(open(p)) if os.path.exists(p) else {}
e=d.setdefault("projects",{}).setdefault(sys.argv[1],{})
e["hasTrustDialogAccepted"]=True; e["hasCompletedProjectOnboarding"]=True
json.dump(d,open(p,"w"),indent=2)
PY

# Launch via the real st launch. It inherits ST_ROOT/COORD_ROOT from this process's env (exported by
# spin.sh) -> the CoS binds the ISOLATED bus. --unattended bakes the startup auto-poker; --session-name
# makes the pty session name collision-proof (never clobbers a live `cos`).
( cd "$d" && st launch claude \
    --identity "$id" \
    --session-name "$pfx" \
    --permission-mode "$mode" \
    --persona "$persona" \
    --unattended )

# Register the EXACT resulting session name so teardown is zero-orphan even though it's outside our prefix stem.
stev_track_extra "$SB" "$sess"

echo "launched $id  (pty session=$sess, --permission-mode $mode, isolated bus=$ROOT, persona=$persona, asyncRewake)"
