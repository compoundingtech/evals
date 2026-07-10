#!/usr/bin/env bash
# Spin TEAM-STANDUP P5 — the LIVE proof (CoS delegates -> specialist executes -> CoS walks) via REAL convoy
# (`convoy add`, ding-default). The spinner convoy-adds the CoS (the same command that onboards a chief-of-
# staff); the CoS then stands up taskflow-dev ITSELF via `convoy add` during the run (that IS the P5 test).
# SELF-ISOLATING: `convoy init`s an isolated network at $SB/st-root; the CoS's `convoy add` inherits its
# ST_ROOT (=$NET) so the stood-up specialist lands on the SAME isolated net. convoy add wires the specialist's
# pre-trust + hooks + ding sidecar itself, so no manual harness pre-staging is needed.
#   ./spin.sh [SANDBOX]        # needs PERSONAS_DIR (bin/ensure-personas.sh provisions it)
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/../../../bin/lib-harness.sh"
SB="${1:-${EVAL_SANDBOX:-./.sandbox}/team-standup}"
NET="$SB/st-root"; export ST_ROOT="$NET"
W="$SB/taskflow"

[ -d "$W" ] || { echo "== sandbox absent — materializing =="; "$HERE/setup-sandbox.sh" "$SB"; }

STEV_NET="$NET"
trap 'rc=$?; [ "$rc" = 0 ] || { echo "== spin rc=$rc — tearing down the isolated net ==" >&2; stev_convoy_teardown "$STEV_NET"; }' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

echo "== 1/4  convoy init the isolated network ($NET) =="
stev_convoy_init "$NET"
echo "== 2/4  compose CoS + specialist personas (standalone files for --persona) =="
"$HERE/compose-persona.sh" cos "$SB"
"$HERE/compose-persona.sh" taskflow-dev "$SB"
echo "== 3/4  pre-create jordan on the isolated bus (the CoS confirms back to them) =="
mkdir -p "$NET/jordan/inbox" "$NET/jordan/archive"; printf 'available\n' > "$NET/jordan/status"
echo "== 4/4  launch the CoS (convoy add: ts-cos, bypass, spawn-capable) — creates its inbox + ding sidecar =="
"$HERE/configure-claude-agent.sh" "$SB"
echo "   seed the delegated task into ts-cos's inbox; its ding sidecar delivers it =="
mkdir -p "$NET/ts-cos/inbox"
ms=$(( $(date +%s) * 1000 )); sfx="$(printf '%06x' "$(( (RANDOM << 8 ^ RANDOM) & 0xffffff ))")"
sed -n '/^---$/,$p' "$HERE/kick-supervisor.md" > "$NET/ts-cos/inbox/${ms}-${sfx}.md"
echo "   seeded $NET/ts-cos/inbox/${ms}-${sfx}.md"

echo
echo "SPUN (TEAM-STANDUP P5, isolated convoy net $NET). members:"; convoy ls "$NET" 2>/dev/null | grep -E 'cos|taskflow' || convoy ls "$NET" 2>/dev/null
echo "OBSERVE (ST_ROOT=$NET): ts-cos boots -> reads Jordan's task -> \`convoy add\` taskflow-dev -> records it in team.md"
echo "  -> briefs taskflow-dev over the bus -> taskflow-dev adds completeTask + test, commits, reports"
echo "  -> cos WALKS read-only (behaves? test real? green? lane held?) -> records done -> confirms to jordan."
echo "GRADE when the loop closes:  fixture/grade.sh \"$SB\""
echo "TEARDOWN after grading:      convoy down \"$NET\"   (then rm -rf \"$SB\")"
