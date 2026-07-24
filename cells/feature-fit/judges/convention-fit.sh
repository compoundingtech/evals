#!/usr/bin/env bash
# JUDGE: convention fit — the discriminator (did the feature match the house style, not just work?).
# HARD gates: K1 no `throw` (the codebase never throws — returns fail()), and K3 registered in index.js.
# SIGNALS (non-gating, surfaced for the reviewer / quality read): K3 module shape { name, describe, run },
# K1 uses ok()/fail() from result.js, K2 reuses validate.js. A functional-but-alien impl trips the WARNs.
#
# PASS (exit 0): rename.js exists, does not throw, and is registered. WARN rows don't affect the verdict.
set -uo pipefail
ROOT="${CATALOG:-$PWD}"; W="$ROOT/worker"
R="$W/src/commands/rename.js"
fail=0
[ -f "$R" ] || { echo "FAIL: src/commands/rename.js does not exist (feature not added in the house structure)"; exit 1; }

if grep -q "throw" "$R"; then
  echo "FAIL: K1 VIOLATION — rename.js uses \`throw\` (the codebase never throws; it returns fail())"; fail=1
else
  echo "PASS: K1 no \`throw\` — follows the Result pattern"
fi
grep -qE "\brename\b" "$W/src/commands/index.js" && echo "PASS: K3 registered in the commands registry (index.js)" \
                                                 || { echo "FAIL: K3 NOT registered in index.js"; fail=1; }

# fit SIGNALS (non-gating) — the idiomatic-fit discriminator, surfaced for the quality read
grep -qE "name:\s*[\"']rename[\"']" "$R" && grep -q "run" "$R" && grep -q "describe" "$R" \
  && echo "  ok: K3 module shape { name, describe, run }" || echo "  WARN: K3 rename.js doesn't match the { name, describe, run } shape"
grep -qE "from \"\.\./result\.js\"" "$R" && grep -qE "\bfail\(|\bok\(" "$R" \
  && echo "  ok: K1 uses ok()/fail() from result.js" || echo "  WARN: K1 doesn't use ok()/fail() from result.js (hand-rolled Result?)"
grep -qE "from \"\.\./validate\.js\"" "$R" \
  && echo "  ok: K2 reuses shared validators from validate.js" || echo "  WARN: K2 doesn't reuse validate.js (inlined its own validation?)"
exit "$fail"
