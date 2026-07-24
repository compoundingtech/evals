#!/usr/bin/env bash
# JUDGE: functional — the new `rename` works via dispatch, which enforces REGISTRATION + the Result shape.
# Four cases (blind to how it was implemented): rename ok; missing id -> not_found; empty title -> invalid;
# bad id -> invalid. A throw, a missing registration, or a wrong shape/codes all fail here.
#
# PASS (exit 0): all four dispatch cases behave correctly.
set -uo pipefail
ROOT="${CATALOG:-$PWD}"; W="$ROOT/worker"
[ -d "$W" ] || { echo "FAIL: no worker repo at $W"; exit 1; }
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
  *FUNC-OK*) echo "PASS: rename is functionally correct via dispatch (registered + returns the Result shape)"; exit 0;;
  *) echo "FAIL: rename FUNCTIONAL failure (unregistered? throws? wrong shape/codes? — see rows above)"; exit 1;;
esac
