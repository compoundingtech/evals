#!/usr/bin/env bash
# Spin TEAM-STANDUP P5 — the LIVE proof (CoS delegates -> specialist executes -> CoS walks) via the REAL
# `st launch`. The SPINNER st-launches the CoS (the same command that onboards a chief-of-staff —
# onboarding.md documents it), so the eval dogfoods the whole launch surface. The CoS then stands up
# taskflow-dev ITSELF via `st launch` during the run (that IS the P5 test — untouched).
# SELF-ISOLATING: creates + exports an isolated bus root ($SB/st-root) so nothing touches the live network;
# the st-launched CoS (and the worker it stands up) inherit ST_ROOT/COORD_ROOT from this process.
# Composes personas, pre-stages the worker's Claude harness startup-gates (so the CoS's stood-up specialist
# doesn't stall — the CoS's own `st launch` still installs the persona + boots it), seeds the hermetic
# kick, and launches the CoS LAST (after the kick lands).
#
#   ./spin.sh [SANDBOX]
#   needs: PERSONAS_DIR (bin/ensure-personas.sh provisions it) + ST_HOOKS_DIR (the worker gate pre-stage the
#          CoS's stood-up specialist relies on). No external ST_ROOT — spin owns the isolated root.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/../../../bin/lib-harness.sh"
SB="${1:-${EVAL_SANDBOX:-./.sandbox}/team-standup}"
STR="$SB/st-root"
W="$SB/taskflow"
export ST_ROOT="$STR"; export COORD_ROOT="$STR"      # st-launched CoS (+ its stood-up worker) -> isolated bus
HOOKS="${ST_HOOKS_DIR:?set ST_HOOKS_DIR to <smalltalk>/examples/claude-code/hooks (worker gate pre-stage)}"
# Collision-proof per-run pty prefix (shared harness). The CoS is ours (st-launched with a stev session
# name); the worker is st-launched by the CoS (named by its identity, outside our prefix), so we register
# it for teardown. configure-claude-agent.sh also registers the EXACT CoS session name.
stev_init "$(basename "$(dirname "$HERE")")" "$SB"; stev_arm_teardown "$SB"
COS_PREFIX="$(stev_prefix "$SB" cos)"; COS_SESSION="cos-${COS_PREFIX}"   # st launch: <identity>-<session-name>
WORKER_PREFIX="taskflow"; WORKER_SESSION="${WORKER_PREFIX}-claude"       # CoS stands up taskflow-dev; register for teardown
stev_track_extra "$SB" "$WORKER_SESSION"

[ -d "$W" ] || { echo "== sandbox absent — materializing =="; "$HERE/setup-sandbox.sh" "$SB"; }
mkdir -p "$STR/cos/inbox" "$STR/cos/archive"         # so the kick can land before the CoS launches

echo "== 1/5  compose CoS + specialist personas (standalone files for st launch --persona) =="
"$HERE/compose-persona.sh" cos "$SB"
"$HERE/compose-persona.sh" taskflow-dev "$SB"

echo "== 2/5  pre-stage the worker's Claude harness startup-gates =="
# FRICTION (recorded): when the CoS stands up the specialist via `st launch`, st launch writes the child's
# pty.toml + .mcp.json + persona + boot hooks, but historically did NOT pre-trust the child's folder — so a
# freshly stood-up specialist could hit the folder-trust + MCP-enable startup gates and stall until a pty
# poke. We pre-stage exactly those gates here (the same harness infra every cell stages); the CoS's live
# `st launch` still installs the persona, generates pty.toml (ST_AGENT=taskflow-dev), and boots the worker
# — the graded acts (spawn, brief, walk) are untouched. (Candidate to trim during the E2E ×2 live run once
# `st launch --unattended` hands-off standup is confirmed end-to-end — flagged to cos.)
python3 - "$W" <<'PY'
import json,os,sys
p=os.path.expanduser("~/.claude.json"); d=json.load(open(p)) if os.path.exists(p) else {}
e=d.setdefault("projects",{}).setdefault(sys.argv[1],{})
e["hasTrustDialogAccepted"]=True; e["hasCompletedProjectOnboarding"]=True
json.dump(d,open(p,"w"),indent=2)
PY
mkdir -p "$W/.claude"
cat > "$W/.claude/settings.local.json" <<JSON
{
  "\$schema": "https://json.schemastore.org/claude-code-settings.json",
  "enabledMcpjsonServers": ["st"],
  "enableAllProjectMcpServers": true,
  "hooks": {
    "SessionStart": [{ "hooks": [{ "type": "command", "command": "$HOOKS/session-start.sh", "async": true, "asyncRewake": true }] }],
    "StopFailure": [{ "hooks": [{ "type": "command", "command": "$HOOKS/stop-failure.sh" }] }]
  }
}
JSON
echo "   pre-trusted $W + staged .claude/settings.local.json (asyncRewake + MCP-enable)"

echo "== 3/5  pre-create jordan on the sandbox bus (the CoS confirms back to them) =="
mkdir -p "$STR/jordan/inbox" "$STR/jordan/archive"; printf 'available\n' > "$STR/jordan/status"

echo "== 4/5  seed the delegated task into the CoS inbox (boot-time ms; strip HTML header) =="
ms=$(( $(date +%s) * 1000 ))
sfx="$(printf '%06x' "$(( (RANDOM << 8 ^ RANDOM) & 0xffffff ))")"
sed -n '/^---$/,$p' "$HERE/kick-supervisor.md" > "$STR/cos/inbox/${ms}-${sfx}.md"
echo "   seeded $STR/cos/inbox/${ms}-${sfx}.md"

echo "== 5/5  launch the CoS via st launch (bypass, spawn-capable) — LAST, after the kick landed =="
"$HERE/configure-claude-agent.sh" "$SB"

echo
echo "SPUN (TEAM-STANDUP P5, isolated bus at $STR). sessions:"
pty ls 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g' | grep -E "$(stev_run_prefix "$SB")|cos-|taskflow-" || pty ls 2>/dev/null || true
echo
echo "OBSERVE the loop (isolated bus at $STR; CoS pty session = $COS_SESSION):"
echo "  cos boots -> reads Jordan's task -> \`st launch\` taskflow-dev -> records it in team.md"
echo "   -> briefs taskflow-dev over the bus -> taskflow-dev adds completeTask + test, commits, reports"
echo "   -> cos WALKS read-only (behaves? test real? green? lane held?) -> records done -> confirms to jordan"
echo
echo "WAKE: Claude auto-wakes via st launch's asyncRewake hook (wired for both). If either idles on a"
echo "  delivered message, poke by hand (a tracked HB-4 poke). The CoS session is $COS_SESSION; the"
echo "  stood-up specialist's session is named by st launch from its identity (taskflow-dev):"
echo "    pty send $COS_SESSION --with-delay 0.4 --seq key:ctrl+u --seq 'read your inbox and proceed' --seq key:return"
echo
echo "GRADE when the loop closes:  fixture/grade.sh \"$SB\""
echo "TEARDOWN after grading:  bin/st-evals teardown \"$SB\""
