#!/usr/bin/env bash
# Run the crash-ding cell for BOTH harnesses and require BOTH to pass — the whole point is that the
# crash->ding path is harness-agnostic, so a codex-only OR claude-only pass is a FAIL. Each harness gets its
# own isolated net; teardown after grading.
#   ./run.sh [SANDBOX_BASE]        # needs CONVOY_BIN (a convoy with the crash-ding emit)
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE="${1:-${EVAL_SANDBOX:-/tmp}/cd}"
CONVOY="${CONVOY_BIN:-convoy}"
overall=0
for H in codex claude; do
  echo "############################## harness: $H ##############################"
  "$HERE/spin.sh" "$H" "$BASE" >/dev/null || { echo "==> crash-ding[$H]: spin FAILED"; overall=1; "$CONVOY" down "$BASE-$H/net" --force >/dev/null 2>&1 || true; continue; }
  "$HERE/grade.sh" "$H" "$BASE"; rc=$?
  [ "$rc" = 0 ] || overall=1
  "$CONVOY" down "$BASE-$H/net" --force >/dev/null 2>&1 || true    # teardown this harness's net
  echo
done
echo "=================================================================="
[ "$overall" = 0 ] && echo "==> crash-ding: PASS — crash->ding fired for BOTH codex AND claude (real ding to cos + supervisor), silent on routine respawns." \
                   || echo "==> crash-ding: FAIL — at least one harness did not satisfy the crash->ding contract (see above)."
exit "$overall"
