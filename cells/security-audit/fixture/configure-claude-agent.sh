#!/usr/bin/env bash
# Launch one Security-audit Claude eval agent via the REAL `st launch` (not a homegrown config writer).
# `st launch` writes .mcp.json (server `st` = coord --channel), .claude/settings.local.json (asyncRewake
# + PreCompact + StopFailure hooks, enableAllProjectMcpServers, enabledMcpjsonServers:["st"]), the
# session-id, pty.toml, installs the composed persona (--persona -> PERSONA.md + @PERSONA.md in CLAUDE.md),
# and starts the pty session. We add the two things st launch does NOT do for an eval:
#   1. ISOLATION (RISK 2): the isolated bus reaches the agent by ENV INHERITANCE — spin.sh exports
#      ST_ROOT/COORD_ROOT before calling this, so `st launch` -> pty session -> claude -> the `st` MCP
#      server all inherit the isolated root (verified live: agent registers on $ST_ROOT, live bus untouched).
#      (When st launch learns to bake ST_ROOT into the generated session env, this stays correct for free.)
#   2. ZERO-ORPHAN TEARDOWN (RISK 1): --session-name "$(stev_prefix ...)" makes the pty session name
#      collision-proof (`<id>-stev-<cell>-<runid>-<id>`, never a bare `<id>-claude`); we register that EXACT
#      name via stev_track_extra so `st-evals teardown` removes it (teardown's prefix-grep extracts the stem
#      mid-string, so the exact full name is load-bearing).
# Plus deterministic startup hygiene st launch leaves to the operator: pre-create the isolated coord dir
# (so the boot ritual doesn't rabbit-hole) and pre-trust the folder (belt-and-suspenders with --unattended).
# Permission POSTURE (the operator): SUPERVISOR = bypassPermissions (spawn-capable); AUDITOR = auto.
#   ./configure-claude-agent.sh <sup|aud> [SANDBOX]   # ST_ROOT must be exported (spin.sh does this)
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/../../../bin/lib-harness.sh"
role="$1"; SB="${2:-${EVAL_SANDBOX:-./.sandbox}/security-audit}"
ROOT="${ST_ROOT:?spin.sh must export ST_ROOT to the isolated bus root ($SB/st-root) before launching}"
stev_init "$(basename "$(dirname "$HERE")")" "$SB"   # collision-proof pty prefix; idempotent (standalone-safe)

case "$role" in
  sup) id="sa-sup"; d="$SB/sup";    mode="bypassPermissions" ;;   # coordinate-only, spawn-capable
  aud) id="sa-aud"; d="$SB/worker"; mode="auto" ;;                # owns the repo; no child agents
  *) echo "role must be sup|aud" >&2; exit 1 ;;
esac
persona="$SB/personas-local/$id.md"
[ -f "$persona" ] || { echo "missing composed persona $persona — run compose-persona.sh $role first" >&2; exit 1; }
# stev-retirement: NO collision-proof prefix, NO track_extra. The run's decoupled short PTY_ROOT (exported by
# spin.sh, honored verbatim by st launch #69) physically isolates every session — the agent AND the `st ding`
# sidecar — from the operator's global pty daemon, so a plain session name is fine and teardown just kills
# everything in the run's PTY_ROOT.

# Pre-create the FULL coord dir on the ISOLATED bus (inbox+archive+status) so the boot ritual doesn't
# rabbit-hole looking for its own folder.
mkdir -p "$ROOT/$id/inbox" "$ROOT/$id/archive"; printf 'available\n' > "$ROOT/$id/status"

# Pre-trust the folder for Claude Code (skip the workspace-trust gate). --unattended also auto-pokes the
# startup gates, but pre-trust is deterministic and cheap — keep both (the auto-poker's fixed timing can miss).
python3 - "$d" <<'PY'
import json,os,sys
p=os.path.expanduser("~/.claude.json")
d=json.load(open(p)) if os.path.exists(p) else {}
e=d.setdefault("projects",{}).setdefault(sys.argv[1],{})
e["hasTrustDialogAccepted"]=True; e["hasCompletedProjectOnboarding"]=True
json.dump(d,open(p,"w"),indent=2)
PY

# Launch via the real st launch. It inherits ST_ROOT/COORD_ROOT from this process's env (exported by
# spin.sh) -> the agent binds the ISOLATED bus. --unattended bakes the startup auto-poker; --session-name
# makes the pty session name collision-proof.
( cd "$d" && st launch claude $(stev_ding_flags) \
    --identity "$id" \
    --session-name run \
    --permission-mode "$mode" \
    --persona "$persona" \
    --unattended )

# (stev-retirement: no stev_track_extra — every session, incl. the ding sidecar, is in the run's PTY_ROOT and
#  is torn down by killing that root. The mid-launch-orphan class is gone by construction.)

echo "launched $id  (pty root=${PTY_ROOT:-?}, session=$id-run$(stev_ding_on && echo " + $id-ding sidecar"), --permission-mode $mode, isolated bus=$ROOT, persona=$persona, asyncRewake)"
