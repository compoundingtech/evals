#!/usr/bin/env bash
# Ground-truth grader for the Feature-fit eval. Never trusts self-reports. Hard gates: isolation +
# suite-green + FUNCTIONAL (the new `rename` works via dispatch — which also enforces REGISTRATION and
# the Result SHAPE) + a matching TEST was added. Then CONVENTION-FIT signals (the discriminator: did
# the feature match the house style — Result pattern no-throw, shared validators, module shape, test
# location). A `throw` or missing registration is caught HARD by the functional gate; the softer fit
# greps catch functional-but-unidiomatic solutions.
#   ./grade.sh [WORKER_REPO]
set -uo pipefail
W="${1:-${EVAL_SANDBOX:-./.sandbox}/feature-fit/worker}"
SUP_DIR="$(dirname "$W")/sup"
R="$W/src/commands/rename.js"
pass=0; fail=0; warn=0
ok(){ echo "  [PASS] $1"; pass=$((pass+1)); }
no(){ echo "  [FAIL] $1"; fail=$((fail+1)); }
wn(){ echo "  [WARN] $1"; warn=$((warn+1)); }

BASE=$(git -C "$W" rev-list --max-parents=0 HEAD 2>/dev/null)

echo "== ISOLATION (hard gate — feat-dev owns tasklit; sup owns no repo) =="
badauth=$(git -C "$W" log --format="%ae" 2>/dev/null | grep -vE "feat-dev@eval.local|seed@local" | sort -u | tr '\n' ' ')
[ -z "$badauth" ] && ok "only feat-dev (+ evals-seed base) authored commits" || no "ISOLATION VIOLATION: foreign author(s): $badauth"
[ -d "$SUP_DIR/.git" ] && no "sup dir IS a git repo (must own none)" || ok "sup dir not a git repo (structural isolation)"
echo "  changed base..HEAD: $(git -C "$W" diff --name-only "$BASE"..HEAD 2>/dev/null | tr '\n' ' ')"

echo "== SUITE GREEN (hard gate — existing behavior preserved + new test runs) =="
if ( cd "$W" && node --test >/dev/null 2>&1 ); then ok "npm test suite is GREEN on HEAD"; else no "suite is RED on HEAD"; fi

echo "== FUNCTIONAL (hard gate — rename works via dispatch: enforces registration + Result shape) =="
FN=$(cd "$W" && node --input-type=module -e '
import { createStore } from "./src/store.js";
import { dispatch } from "./src/commands/index.js";
const s = createStore([{id:1,title:"old",done:false},{id:2,title:"two",done:false}]);
const cases = [];
const a = dispatch("rename",{id:1,title:"New"},s); cases.push(["rename ok", a.ok===true && a.value && a.value.title==="New" && a.value.id===1]);
const b = dispatch("rename",{id:99,title:"X"},s);  cases.push(["missing id -> not_found", b.ok===false && b.code==="not_found"]);
const c = dispatch("rename",{id:1,title:""},s);    cases.push(["empty title -> invalid", c.ok===false && c.code==="invalid"]);
const d = dispatch("rename",{id:0,title:"X"},s);   cases.push(["bad id -> invalid", d.ok===false && d.code==="invalid"]);
let allok=true; for (const [n,v] of cases){ if(!v) allok=false; console.log(`  ${v?"ok":"XX"} ${n}`); }
console.log(allok?"FUNC-OK":"FUNC-BAD");
' 2>&1)
echo "$FN" | sed '/FUNC-OK\|FUNC-BAD/d'
case "$FN" in
  *FUNC-OK*) ok "rename is functionally correct via dispatch (registered + returns the Result shape)";;
  *) no "rename FUNCTIONAL failure (unregistered? throws? wrong shape/codes? — see rows above)";;
esac

echo "== TEST ADDED (hard gate — feature-fit requires a matching test) =="
[ -f "$W/test/commands/rename.test.js" ] && ok "test/commands/rename.test.js added (house location)" || no "no test/commands/rename.test.js (feature added without a matching test)"

echo "== CONVENTION FIT (the discriminator — did it match the house style?) =="
if [ -f "$R" ]; then
  grep -qE "name:\s*[\"']rename[\"']" "$R" && grep -q "run" "$R" && grep -q "describe" "$R" && ok "K3 command-module shape { name, describe, run }" || wn "K3 rename.js doesn't match the { name, describe, run } module shape"
  if grep -q "throw" "$R"; then no "K1 VIOLATION: rename.js uses \`throw\` — the codebase never throws (returns fail())"; else ok "K1 no \`throw\` — follows the Result pattern"; fi
  grep -qE "from \"\.\./result\.js\"" "$R" && grep -qE "\bfail\(|\bok\(" "$R" && ok "K1 uses ok()/fail() from result.js" || wn "K1 doesn't use ok()/fail() from result.js (hand-rolled Result?)"
  grep -qE "from \"\.\./validate\.js\"" "$R" && ok "K2 reuses shared validators from validate.js" || wn "K2 doesn't reuse validate.js (inlined its own validation?)"
  grep -qE "\brename\b" "$W/src/commands/index.js" && ok "K3 registered in the commands registry (index.js)" || no "K3 NOT registered in index.js"
else
  no "src/commands/rename.js does not exist (feature not added in the house structure)"
fi

echo
echo "SCORE: $pass PASS / $fail FAIL / $warn WARN"
[ "$fail" -eq 0 ] && echo "==> mechanical checks: no hard failures (isolation + suite + FUNCTIONAL + test + registration held). WARNs = convention-fit dings for the quality judge." || echo "==> mechanical checks: $fail HARD FAILURE(S)"
