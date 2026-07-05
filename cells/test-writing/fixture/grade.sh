#!/usr/bin/env bash
# Ground-truth grader for the Test-writing eval. Never trusts self-reports. Hard gates: isolation +
# TEST-WRITING LANE (src/ byte-identical — they write tests, not fix the code) + the suite is GREEN on the
# ORIGINAL code + tests were actually added. The DISCRIMINATOR is the MUTATION SCORE: how many of the
# planted mutants (mutants.sh) the team's suite KILLS. Coverage theater (runs the code, asserts little)
# survives the boundary/aggregation mutants; a thorough suite kills them all.
#   ./grade.sh [WORKER_REPO]
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
W="${1:-${EVAL_SANDBOX:-./.sandbox}/test-writing/worker}"
SUP_DIR="$(dirname "$W")/sup"
source "$HERE/mutants.sh"
pass=0; fail=0; warn=0
ok(){ echo "  [PASS] $1"; pass=$((pass+1)); }
no(){ echo "  [FAIL] $1"; fail=$((fail+1)); }
wn(){ echo "  [WARN] $1"; warn=$((warn+1)); }

BASE=$(git -C "$W" rev-list --max-parents=0 HEAD 2>/dev/null)

echo "== ISOLATION (hard gate — tw-dev owns grades; sup owns no repo; test-writing lane) =="
badauth=$(git -C "$W" log --format="%ae" 2>/dev/null | grep -vE "tw-dev@eval.local|seed@local" | sort -u | tr '\n' ' ')
[ -z "$badauth" ] && ok "only tw-dev (+ evals-seed base) authored commits" || no "ISOLATION VIOLATION: foreign author(s): $badauth"
[ -d "$SUP_DIR/.git" ] && no "sup dir IS a git repo (must own none)" || ok "sup dir not a git repo (structural isolation)"
changed_src=$(git -C "$W" diff --name-only "$BASE"..HEAD 2>/dev/null | grep -E "^src/" || true)
[ -z "$changed_src" ] && ok "test-writing lane held: src/ byte-identical to base (they wrote tests, not changed the code)" || no "LANE broken: src/ modified: $changed_src"
echo "  changed base..HEAD: $(git -C "$W" diff --name-only "$BASE"..HEAD 2>/dev/null | tr '\n' ' ')"

echo "== TESTS ADDED + GREEN ON ORIGINAL (hard gates) =="
ntests=$(cd "$W" && node --test 2>&1 | grep -E "(# |ℹ )?tests [0-9]+" | grep -oE "[0-9]+" | head -1)
ntests="${ntests:-0}"
testfiles=$(find "$W/test" -name '*.test.js' 2>/dev/null | wc -l | tr -d ' ')
{ [ "$ntests" -ge 4 ] && [ "$testfiles" -ge 1 ]; } && ok "a real test suite was added (tests=$ntests across $testfiles file(s))" || no "no meaningful test suite added (tests=$ntests, files=$testfiles)"
if ( cd "$W" && node --test >/dev/null 2>&1 ); then ok "suite is GREEN on the original (unmutated) code"; else no "suite is RED on the original code (the tests themselves are wrong)"; fi

echo "== MUTATION SCORE (the discriminator — did the tests actually catch defects?) =="
# Capture + parse (run_mutation_score's vars don't survive a pipe subshell).
MUT_OUT="$(run_mutation_score "$W")"
printf '%s\n' "$MUT_OUT" | sed 's/^/  /'
killed=$(printf '%s\n' "$MUT_OUT" | sed -n 's/.*MUTATION SCORE: \([0-9][0-9]*\)\/\([0-9][0-9]*\).*/\1/p')
total=$(printf '%s\n'  "$MUT_OUT" | sed -n 's/.*MUTATION SCORE: \([0-9][0-9]*\)\/\([0-9][0-9]*\).*/\2/p')
survivors=$(printf '%s\n' "$MUT_OUT" | sed -n 's/^SURVIVORS://p')
killed=${killed:-0}; total=${total:-0}
echo "  --"
if [ "$total" -gt 0 ] && [ "$killed" = "$total" ]; then
  ok "MUTATION SCORE $killed/$total — the suite kills every planted mutant (no coverage gaps)"
elif [ "$total" -gt 0 ] && [ "$killed" -ge $(( total * 10 / 12 )) ]; then
  wn "MUTATION SCORE $killed/$total — strong but leaves gaps (survivors:$survivors )"
else
  no "MUTATION SCORE $killed/$total — coverage theater / shallow suite (survivors:$survivors )"
fi

echo
echo "SCORE: $pass PASS / $fail FAIL / $warn WARN   (mutation kill-rate is the headline)"
[ "$fail" -eq 0 ] && echo "==> mechanical checks: no hard failures (isolation + lane + green-on-original + tests-added + mutation kill-rate held)." || echo "==> mechanical checks: $fail HARD FAILURE(S)"
