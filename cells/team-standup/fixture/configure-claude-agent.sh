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
#      ST_ROOT before calling this, so st launch -> pty session -> claude -> the `st` MCP server
#      inherit the isolated root (and post-#52 st also bakes ST_ROOT into the generated session env).
#   2. ZERO-ORPHAN + NO-CLOBBER (RISK 1): spin.sh exports the run's decoupled PTY_ROOT and `st launch` honors
#      it verbatim (smalltalk #69), so the CoS session lands in that isolated root — off the operator's global
#      pty daemon, so it can NEVER clobber a live `cos`; teardown removes the whole root, zero-orphan.
# Posture: CoS = bypassPermissions (spawn-capable — it shells `st launch` + `pty up` to stand up the worker).
#   ./configure-claude-agent.sh [SANDBOX]   # ST_ROOT must be exported (spin.sh does this)
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/../../../bin/lib-harness.sh"
SB="${1:-${EVAL_SANDBOX:-./.sandbox}/team-standup}"
ROOT="${ST_ROOT:?spin.sh must export ST_ROOT to the isolated bus root ($SB/st-root) before launching}"
stev_init "$(basename "$(dirname "$HERE")")" "$SB"   # mint the run's decoupled PTY_ROOT (short, per-run); idempotent (standalone-safe)

id="cos"; d="$SB/cos"; mode="bypassPermissions"      # coordinate-only, spawn-capable; owns NO repo
persona="$SB/personas-local/$id.md"
[ -f "$persona" ] || { echo "missing composed persona $persona — run compose-persona.sh cos first" >&2; exit 1; }
# stev-retirement: NO collision-proof prefix, NO track_extra. The run's decoupled short PTY_ROOT (exported by
# spin.sh, honored verbatim by st launch #69) physically isolates the CoS session (and its ding sidecar) from
# the operator's global pty daemon — so `--session-name run` can NEVER clobber a live `cos`, and teardown just
# kills everything in the run's PTY_ROOT (incl. the worker the CoS stands up, which inherits PTY_ROOT).

# Pre-create the FULL st dir on the ISOLATED bus so the boot ritual doesn't rabbit-hole.
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

# Launch via the real st launch. It inherits ST_ROOT from this process's env (exported by
# spin.sh) -> the CoS binds the ISOLATED bus. --unattended bakes the startup auto-poker; the run's decoupled
# PTY_ROOT keeps this session off the operator's global pty daemon (so it never clobbers a live `cos`).
( cd "$d" && st launch claude $(stev_ding_flags) \
    --identity "$id" \
    --session-name run \
    --permission-mode "$mode" \
    --persona "$persona" \
    --unattended )

# (stev-retirement: no per-session teardown registration — the CoS session + its ding sidecar are in the run's PTY_ROOT and
#  torn down by killing that root. The mid-launch-orphan class is gone by construction.)

echo "launched $id  (pty root=${PTY_ROOT:-?}, session=$id-run$(stev_ding_on && echo " + $id-ding sidecar"), --permission-mode $mode, isolated bus=$ROOT, persona=$persona, asyncRewake)"
