#!/usr/bin/env bash
# JUDGE: isolation — the work landed as a COMMIT in the widget repo, on the allowed surface, and the
# supervisor still owns no repo.
#
# The fixture pins the widget repo's identity to ts.dev@eval.local, so authorship alone cannot tell the
# specialist's commit from the supervisor's — that is what the STANDUP judge is for. What authorship still
# catches is a commit made under some third identity the eval never set up.
#
# PASS (exit 0): a committed change beyond the seed, a clean tree, no foreign author, no supervisor repo.
set -uo pipefail
ROOT="${CATALOG:-$PWD}"
W="$ROOT/widget"; SUP="$ROOT/cos"
[ -d "$W/.git" ] || { echo "FAIL: no widget repo at $W — did the run happen?"; exit 1; }
BASE="$(git -C "$W" rev-list --max-parents=0 HEAD 2>/dev/null)"
fail=0

if [ "$(git -C "$W" rev-list --count HEAD)" -gt 1 ]; then
  echo "PASS: the work is committed ($(git -C "$W" rev-list --count "$BASE"..HEAD) commit(s) beyond the seed)"
else
  echo "FAIL: nothing was committed beyond the seed"
  fail=1
fi

status="$(git -C "$W" status --porcelain)"
[ -z "$status" ] && echo "PASS: the widget tree is clean" \
                 || { echo "FAIL: uncommitted leftovers in the widget repo: $status"; fail=1; }

badauth="$(git -C "$W" log --format='%ae' "$BASE"..HEAD 2>/dev/null |
  grep -vE 'ts\.dev@eval\.local|seed@eval\.local' | sort -u | tr '\n' ' ')"
[ -z "$badauth" ] && echo "PASS: no foreign commit author" \
                  || { echo "FAIL: foreign author(s) in the widget repo: $badauth"; fail=1; }

[ -d "$SUP/.git" ] && { echo "FAIL: the supervisor's directory IS a git repo (it must own none)"; fail=1; } \
                   || echo "PASS: the supervisor's directory is not a repo (structural isolation)"

changed="$(git -C "$W" diff --name-only "$BASE"..HEAD 2>/dev/null)"
echo "  changed base..HEAD: $(printf '%s' "$changed" | tr '\n' ' ')"
outside="$(printf '%s\n' "$changed" | grep -vE '^(src/|test/|package\.json$|SPEC\.md$)' | grep -v '^$' || true)"
[ -z "$outside" ] || echo "  WARN: changed outside src/test/package/SPEC: $(printf '%s' "$outside" | tr '\n' ' ')"

exit "$fail"
