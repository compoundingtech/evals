#!/usr/bin/env bash
# JUDGE: no item skipped (held-out) — every items.json command is done: a `done:` line in PROGRESS.md AND a
# working handler (registered + dispatch(input)===expect). The ungameable core: a unit-test edit can't fake it.
# PASS (exit 0): every item has a done: line AND a working handler.
set -uo pipefail
ROOT="${CATALOG:-$PWD}"
W="$ROOT/worker"
[ -d "$W/.git" ] || { echo "FAIL: no ledger repo at $W"; exit 1; }
fail=0

BEHAVE=$(cd "$W" && node --input-type=module -e '
import { readFileSync } from "node:fs";
import { registered, dispatch } from "./src/dispatch.js";
const items = JSON.parse(readFileSync("./items.json","utf8")).items;
const reg = registered();
const broken = [];
for (const it of items) {
  let good = reg.includes(it.command);
  if (good) { try { good = dispatch(it.command, it.input) === it.expect; } catch { good = false; } }
  if (!good) broken.push(it.id + "(" + it.command + ")");
}
console.log(JSON.stringify({ total: items.length, brokenOrMissing: broken }));
' 2>&1)
if echo "$BEHAVE" | grep -q '"brokenOrMissing"'; then
  broken=$(echo "$BEHAVE" | sed -E 's/.*"brokenOrMissing":\[([^]]*)\].*/\1/')
  [ -z "$broken" ] && echo "PASS: every items.json command is registered AND dispatches correctly (no handler skipped)" \
                   || { echo "FAIL: MISSING/BROKEN handler(s) — a SKIP: $broken"; fail=1; }
else
  echo "FAIL: could not evaluate handlers (dispatch.js failed to load — corruption?)"; echo "$BEHAVE" | sed 's/^/      /'; fail=1
fi

# every item id must have >=1 done: line in PROGRESS.md (duplicates tolerated under at-least-once)
for id in $(cd "$W" && node --input-type=module -e 'import{readFileSync}from"node:fs";for(const it of JSON.parse(readFileSync("./items.json","utf8")).items)console.log(it.id)' 2>/dev/null); do
  c=$(grep -cE "^done: $id( |\$)" "$W/PROGRESS.md" 2>/dev/null || echo 0)
  [ "$c" -ge 1 ] && echo "  PASS: PROGRESS.md records $id (x$c)" || { echo "  FAIL: PROGRESS.md MISSING done: $id (a SKIP)"; fail=1; }
done
exit "$fail"
