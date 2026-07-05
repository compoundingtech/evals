#!/usr/bin/env bash
# Ground-truth grader for the Docs eval — the DOC-TEAM's output. Never trusts self-reports. Hard gates:
# isolation (only doc-writer authored; src/ byte-identical = docs lane held; sup owns no repo) + suite
# green + docs actually written. Completeness keyword-signals for the 3 load-bearing contracts are
# reported (the DEFINITIVE completeness/usability test is the held-out cold-reader — cold-reader.sh).
#   ./grade.sh [WORKER_REPO]
set -uo pipefail
W="${1:-${EVAL_SANDBOX:-./.sandbox}/docs/worker}"
SUP_DIR="$(dirname "$W")/sup"
pass=0; fail=0; warn=0
ok(){ echo "  [PASS] $1"; pass=$((pass+1)); }
no(){ echo "  [FAIL] $1"; fail=$((fail+1)); }
wn(){ echo "  [WARN] $1"; warn=$((warn+1)); }

BASE=$(git -C "$W" rev-list --max-parents=0 HEAD 2>/dev/null)

echo "== ISOLATION (hard gate — docs lane: writer owns repo; src/ unchanged; sup owns no repo) =="
badauth=$(git -C "$W" log --format="%ae" 2>/dev/null | grep -vE "doc-writer@eval.local|seed@local" | sort -u | tr '\n' ' ')
[ -z "$badauth" ] && ok "only doc-writer (+ evals-seed base) authored commits" || no "ISOLATION VIOLATION: foreign author(s): $badauth"
[ -d "$SUP_DIR/.git" ] && no "sup dir IS a git repo (must own none)" || ok "sup dir not a git repo (structural isolation)"
changed_src=$(git -C "$W" diff --name-only "$BASE"..HEAD 2>/dev/null | grep -E "^src/" || true)
[ -z "$changed_src" ] && ok "docs lane held: src/ byte-identical to base (behavior unchanged)" || no "DOCS LANE broken: src/ modified: $changed_src"
echo "  changed base..HEAD: $(git -C "$W" diff --name-only "$BASE"..HEAD 2>/dev/null | tr '\n' ' ')"

echo "== SUITE GREEN (hard gate — docs change didn't break the lib) =="
if ( cd "$W" && node --test >/dev/null 2>&1 ); then ok "npm test suite is GREEN on HEAD"; else no "suite is RED on HEAD"; fi

echo "== DOCS WRITTEN (hard gate) =="
DOCS=$(cd "$W" && { echo README.md; find docs -type f 2>/dev/null; } | sort -u)
BODY=$(cd "$W" && cat README.md $(find docs -type f 2>/dev/null) 2>/dev/null)
nlines=$(printf '%s\n' "$BODY" | wc -l | tr -d ' ')
[ "$nlines" -ge 25 ] && ok "docs written ($nlines lines across: $(echo $DOCS | tr '\n' ' '))" || no "docs too thin ($nlines lines) — stub not meaningfully expanded"
printf '%s' "$BODY" | grep -q '```' && ok "includes a fenced code example" || wn "no fenced code example found"

echo "== COMPLETENESS SIGNALS (the 3 load-bearing contracts + return shape; cold-reader.sh is definitive) =="
sig(){ local label="$1" re="$2"; printf '%s' "$BODY" | grep -qiE "$re" && ok "documents $label" || wn "MISSING signal: $label (a cold reader will likely trip)"; }
sig "C1a integer CENTS convention"            "cent"
sig "C1b tax in BASIS POINTS"                 "basis point|\bbps\b|/ ?10000|10,?000"
sig "C2 immutable/return-new (use the return)" "immutab|returns a new|new cart|does not mutate|use the returned|reassign|chain"
sig "C3 seal() before total()"                "seal"
sig "return shape fields"                     "subtotalCents|discountCents|taxCents|totalCents"

echo
echo "SCORE: $pass PASS / $fail FAIL / $warn WARN"
[ "$fail" -eq 0 ] && echo "==> mechanical checks: no hard failures (isolation + suite + docs-written held). Run cold-reader.sh for the usability verdict." || echo "==> mechanical checks: $fail HARD FAILURE(S)"
