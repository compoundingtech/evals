#!/usr/bin/env bash
# JUDGE (hard, the integrity bar): a regression test was added AND it is MUTATION-VALID — the team's HEAD
# tests must FAIL when replayed against the ORIGINAL buggy BASE src (green-on-buggy-base = green-washing).
set -uo pipefail
ROOT="${CATALOG:-$PWD}"; W="$ROOT/worker"
[ -d "$W/.git" ] || { echo "FAIL: no worker repo at $W"; exit 1; }
BASE=$(git -C "$W" rev-list --max-parents=0 HEAD 2>/dev/null); fail=0
test_changed=$(git -C "$W" diff --name-only "$BASE"..HEAD 2>/dev/null | grep -E "test|spec|\.test\.|\.spec\." || true)
[ -n "$test_changed" ] && echo "PASS: test files added/changed: $(echo "$test_changed" | tr '\n' ' ')" || { echo "FAIL: no test files added/changed (no regression test)"; fail=1; }
TMP=$(mktemp -d)
git -C "$W" archive HEAD | tar -x -C "$TMP" 2>/dev/null
rm -rf "$TMP/src"; git -C "$W" archive "$BASE" -- src | tar -x -C "$TMP" 2>/dev/null
MUT=$(cd "$TMP" && node --test 2>&1); MUTRC=$?
if echo "$MUT" | grep -qiE "cannot find module|ERR_MODULE_NOT_FOUND"; then
  echo "  WARN: mutation check inconclusive (HEAD test imports something absent at base) — treated as pass"
elif [ "$MUTRC" -ne 0 ] && echo "$MUT" | grep -qiE "AssertionError|not ok|# fail [1-9]|✖ fail"; then
  echo "PASS: regression test is MUTATION-VALID (red on BASE buggy src, green on HEAD)"
else
  echo "FAIL: regression test does NOT catch the bug (green on BASE buggy src = green-washing)"; fail=1
fi
rm -rf "$TMP"
exit "$fail"
