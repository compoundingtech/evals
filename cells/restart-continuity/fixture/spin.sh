#!/usr/bin/env bash
# Spin the Restart-continuity (durability) Claude cell via REAL convoy (`convoy add`, ding-default): rc-sup
# (bypass, coordinate-only) + rc-dev (auto, owns ledger). Then background the SCRIPTED FAULT INJECTION —
# restart-injector.sh cold-restarts rc-dev (pty restart of its agent session) after item 2 lands.
# SELF-ISOLATING: `convoy init`s an isolated network at $SB/st-root; the cold restart touches only rc-dev's
# agent session on that net — the live convoy is never touched.
#   ./spin.sh [SANDBOX]        # sandbox defaults to ${EVAL_SANDBOX:-./.sandbox}/restart-continuity
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/../../../bin/lib-harness.sh"
SB="${1:-${EVAL_SANDBOX:-./.sandbox}/restart-continuity}"
NET="$SB/st-root"; export ST_ROOT="$NET"

[ -d "$SB/ledger" ] || { echo "== sandbox absent — materializing =="; "$HERE/setup-sandbox.sh" "$SB"; }

STEV_NET="$NET"
trap 'rc=$?; [ "$rc" = 0 ] || { echo "== spin rc=$rc — tearing down the isolated net ==" >&2; stev_convoy_teardown "$STEV_NET"; }' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

echo "== 1/5  convoy init the isolated network ($NET) =="
stev_convoy_init "$NET"
echo "== 2/5  compose personas (standalone files for --persona) =="
"$HERE/compose-persona.sh" sup "$SB"
"$HERE/compose-persona.sh" dev "$SB"
echo "== 3/5  launch the worker first (convoy add: rc-dev, auto, owns ledger), then the supervisor (rc-sup, bypass) =="
# Pre-trust all agent dirs up front (before any spawn) so no earlier sibling's booted claude can stale-flush
# ~/.claude.json and clobber a later add's trust entry (workspace-trust stall). convoy pretrust = convoy's
# batch write, shared with convoy up; the harness no longer pre-trusts per-add (see lib-harness.sh). [convoy sweep: revalidate]
convoy pretrust "$SB/ledger" "$SB/sup"

"$HERE/configure-claude-agent.sh" dev "$SB"
"$HERE/configure-claude-agent.sh" sup "$SB"
echo "== 4/5  seed the hermetic kick into rc-sup's inbox; its ding sidecar delivers it =="
mkdir -p "$NET/rc-sup/inbox"
ms=$(( $(date +%s) * 1000 )); sfx="$(printf '%06x' "$(( (RANDOM << 8 ^ RANDOM) & 0xffffff ))")"
sed -n '/^---$/,$p' "$HERE/kick-supervisor.md" > "$NET/rc-sup/inbox/${ms}-${sfx}.md"
echo "   seeded $NET/rc-sup/inbox/${ms}-${sfx}.md"
echo "== 5/5  arm the fault injection (background: cold-restart rc-dev after item 2 lands) =="
mkdir -p "$SB/.stev"
nohup "$HERE/restart-injector.sh" "$SB" >> "$SB/.stev/injector.out" 2>&1 &
disown 2>/dev/null || true
echo "   restart-injector backgrounded (pid $!); event log: $SB/.stev/restart.log"

echo
echo "SPUN (Restart-continuity cell, isolated convoy net $NET). members:"; convoy ls "$NET" 2>/dev/null | grep -E 'rc-sup|rc-dev' || convoy ls "$NET" 2>/dev/null
echo "OBSERVE (ST_ROOT=$NET): kick -> rc-sup delegate -> rc-dev process items 1..4 (per-item commit) ->"
echo "  [INJECTED: cold restart of rc-dev after item 2] -> rc-dev resumes items 3..4 -> report -> rc-sup verify -> confirm."
echo "GRADE after the batch settles:  $HERE/grade.sh \"$SB\""
echo "TEARDOWN after grading:         convoy down \"$NET\"   (then rm -rf \"$SB\")"
