#!/usr/bin/env bash
# JUDGE (hard, held-out): slugify meets the spec on all held-out cases (run, not eyeballed) + suite green +
# a change was committed.
set -uo pipefail
ROOT="${CATALOG:-$PWD}"; W="$ROOT/worker"
[ -d "$W/.git" ] || { echo "FAIL: no worker repo at $W"; exit 1; }
BASE=$(git -C "$W" rev-list --max-parents=0 HEAD 2>/dev/null); fail=0
BEHAVE=$(cd "$W" && node --input-type=module -e '
import { slugify } from "./src/slug.js";
const cases = [["Hello World","hello-world"],["Foo_Bar Baz","foo-bar-baz"],["  Trim Me  ","trim-me"],["A.B.C","a-b-c"],["Rock & Roll!","rock-roll"]];
let bad = [];
for (const [inp,exp] of cases) { let got; try { got = slugify(inp); } catch(e){ got = "THREW:"+e.message; } if (got !== exp) bad.push(JSON.stringify(inp)+" => "+JSON.stringify(got)+" (want "+JSON.stringify(exp)+")"); }
console.log(bad.length ? "WRONG: "+bad.join(" | ") : "CORRECT");
' 2>&1)
echo "$BEHAVE" | grep -qx "CORRECT" && echo "PASS: slugify meets the spec on all held-out cases" || { echo "FAIL: slugify WRONG — $BEHAVE"; fail=1; }
( cd "$W" && node --test >/dev/null 2>&1 ) && echo "PASS: npm test suite is GREEN on HEAD" || { echo "FAIL: suite is RED on HEAD"; fail=1; }
CHANGED=$(git -C "$W" diff --name-only "$BASE"..HEAD 2>/dev/null | tr '\n' ' ')
[ -n "$CHANGED" ] && echo "  changed base..HEAD: $CHANGED" || { echo "FAIL: no committed change (dm.dev did not do the work)"; fail=1; }
exit "$fail"
