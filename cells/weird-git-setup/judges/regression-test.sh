#!/usr/bin/env bash
# A REGRESSION TEST was added: the COMMITTED test file has MORE cases than the seed's 3 (the agent added a test
# that would catch this exact bug, not just patched the source).
set -uo pipefail
SB="${CATALOG:?CATALOG not set}"; WT="$SB/wt/feature"
n="$(git -C "$WT" show HEAD:test/clamp.test.js 2>/dev/null | grep -cE '^[[:space:]]*test\(' || echo 0)"
[ "${n:-0}" -ge 4 ] || { echo "FAIL: committed test/clamp.test.js has $n test cases (seed had 3) — no regression test added"; exit 1; }
echo "PASS: a regression test was committed (test/clamp.test.js has $n cases; seed had 3)"
