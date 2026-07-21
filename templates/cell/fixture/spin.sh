#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# TEMPLATE — copy to cells/<name>/fixture/spin.sh (TEAM cells only; deterministic cells ship a
# probe.sh/run.sh instead). Launch the cell via REAL convoy (ding-default, no MCP), SELF-ISOLATED:
# `convoy init`s a throwaway network at $SB/st-root so nothing touches the operator's live convoy.
# NB (convoy 0.2.x is DECLARATIVE): `convoy add` only DECLARES a seat — the harness's stev_convoy_add
# follows it with `convoy up --once "$NET"` to actually SPAWN. That is what makes launch real.
#
#   ./spin.sh [SANDBOX]        # sandbox defaults to ${EVAL_SANDBOX:-./.sandbox}/<name>
#   needs: PERSONAS_DIR (bin/ensure-personas.sh provisions it).
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/../../../bin/lib-harness.sh"
SB="${1:-${EVAL_SANDBOX:-./.sandbox}/TODO_name}"
NET="$SB/st-root"                                   # SELF-ISOLATED convoy network (never the live one)
export ST_ROOT="$NET"
SUP_ID="${SUP_ID:-TODO-sup}"; WORKER_ID="${WORKER_ID:-TODO-worker}"
export SUP_ID WORKER_ID                             # configure-*-agent.sh reads these under `set -u`

[ -d "$SB/worker" ] || { echo "== sandbox absent — materializing =="; "$HERE/setup-sandbox.sh" "$SB"; }

# teardown on CRASH/Ctrl-C/early-exit; LEAVE the team up on a clean spin (agents run async).
STEV_NET="$NET"
trap 'rc=$?; [ "$rc" = 0 ] || { echo "== spin rc=$rc — tearing down $STEV_NET ==" >&2; stev_convoy_teardown "$STEV_NET"; }' EXIT
trap 'exit 130' INT; trap 'exit 143' TERM

echo "== 1/5  convoy init the isolated network ($NET) =="
stev_convoy_init "$NET"

echo "== 2/5  compose personas (standalone files for --persona) =="
"$HERE/compose-persona.sh" sup    claude "$SB"
"$HERE/compose-persona.sh" worker claude "$SB"

echo "== 3/5  launch the worker first (owns the repo) =="
convoy pretrust "$SB/sup" "$SB/worker"              # batch-trust all dirs BEFORE any spawn (avoids trust races)
"$HERE/configure-claude-agent.sh" worker "$SB"     # internally: convoy add + up --once → real spawn

echo "== 4/5  launch the coordinate-only supervisor =="
"$HERE/configure-claude-agent.sh" sup "$SB"

echo "== 5/5  seed the hermetic kick into $SUP_ID's inbox; the ding sidecar delivers it =="
mkdir -p "$NET/$SUP_ID/inbox"; mkdir -p "$SB/.stev"
ms=$(( $(date +%s) * 1000 ))
sfx="$(printf '%06x' "$(( (RANDOM << 8 ^ RANDOM) & 0xffffff ))")"
kf="${ms}-${sfx}.md"
sed -n '/^---$/,$p' "$HERE/kick.md" > "$NET/$SUP_ID/inbox/$kf"
echo "$kf" > "$SB/.stev/kick-filename"              # grade.sh reads this to prove threaded replies
echo "   seeded $NET/$SUP_ID/inbox/$kf"

echo
echo "SPUN (<name>, isolated net $NET). Observe the loop; then grade.sh + teardown."
echo "TEARDOWN after grading:  convoy down \"$NET\"   (then rm -rf \"$SB\")"
