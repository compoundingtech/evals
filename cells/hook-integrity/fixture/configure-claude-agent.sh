#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# hook-integrity — launch the single probe agent via the REAL `st launch claude`, for ONE leg:
#   on)  st launch claude              → hooks WIRED (.claude/settings.local.json written).
#   off) st launch claude --no-hooks   → hooks SKIPPED (the negative control).
# Everything else is identical between the two legs (same persona, same repo, same seeded now.md
# token, MCP on in both) so the ONLY variable is whether the SessionStart hook exists. That is what
# lets the token's presence be attributed 100% to the hook firing.
#
# Same isolation + zero-orphan discipline as the other cells: spin/run.sh exports ST_ROOT for THIS leg's
# isolated bus; st launch inherits it; and run.sh exports the leg's decoupled PTY_ROOT (honored verbatim by
# st launch #69) so every session lands in it and teardown removes the whole root.
#
#   ./configure-claude-agent.sh <on|off> [SANDBOX]   # ST_ROOT must be exported (run.sh does this per-leg)
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/../../../bin/lib-harness.sh"
leg="$1"; SB="${2:-${EVAL_SANDBOX:-./.sandbox}/hook-integrity}"
ROOT="${ST_ROOT:?run.sh must export ST_ROOT to this leg isolated bus root before launching}"
case "$leg" in
  on)  hooks_flag=();            hlabel="WIRED" ;;
  off) hooks_flag=(--no-hooks);  hlabel="SKIPPED" ;;
  *)   echo "leg must be on|off" >&2; exit 1 ;;
esac

id="hi-agent"; d="$SB/repo"
persona="$SB/personas-local/$id.md"
[ -f "$persona" ] || { echo "missing composed persona $persona — run setup-sandbox.sh first" >&2; exit 1; }
stev_init "$(basename "$(dirname "$HERE")")" "$SB"   # mint the run's decoupled PTY_ROOT (per-SB runid); idempotent
# stev-retirement: NO collision-proof prefix, NO track_extra. Each leg runs in its OWN sandbox -> its own
# decoupled short PTY_ROOT (run.sh exports it), so a plain per-leg session name (`$leg`) isolates the agent +
# ding sidecar from the operator's pty daemon, and teardown kills the leg's whole PTY_ROOT.

# Pre-create the FULL st dir on the ISOLATED bus (inbox/archive/context/status already seeded by
# setup-sandbox; mkdir -p is idempotent so the boot ritual doesn't rabbit-hole on a missing dir).
mkdir -p "$ROOT/$id/inbox" "$ROOT/$id/archive" "$ROOT/$id/context"
[ -f "$ROOT/$id/status" ] || printf 'offline\n' > "$ROOT/$id/status"

# Pre-trust the folder for Claude Code (skip the workspace-trust gate). Belt-and-suspenders with --unattended.
python3 - "$d" <<'PY'
import json,os,sys
p=os.path.expanduser("~/.claude.json")
d=json.load(open(p)) if os.path.exists(p) else {}
e=d.setdefault("projects",{}).setdefault(sys.argv[1],{})
e["hasTrustDialogAccepted"]=True; e["hasCompletedProjectOnboarding"]=True
json.dump(d,open(p,"w"),indent=2)
PY

# Launch via the real st launch. Inherits ST_ROOT from run.sh → binds THIS leg's isolated
# bus. bypassPermissions + --unattended keep the probe frictionless so the ONLY thing under test is
# whether the SessionStart hook fires (not permission/trust gates).
( cd "$d" && st launch claude $(stev_ding_flags) "${hooks_flag[@]}" \
    --identity "$id" \
    --session-name "$leg" \
    --permission-mode bypassPermissions \
    --persona "$persona" \
    --unattended )

# (stev-retirement: no per-session teardown registration — the leg's PTY_ROOT holds the agent + ding sidecar; teardown kills
#  the root. The --ding toggle is applied identically on BOTH legs, so the SessionStart hook stays the only
#  on/off variable — and under --ding this leg proves the hook fires with NO MCP: the MCP-hostile-host case.)

echo "launched $id  (leg=$leg, hooks=$hlabel; pty root=${PTY_ROOT:-?}, session=$id-$leg$(stev_ding_on && echo " + $id-ding sidecar"), isolated bus=$ROOT)"
