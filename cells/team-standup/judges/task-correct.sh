#!/usr/bin/env bash
# JUDGE: task correct (held-out) — completeTask BEHAVES + the suite is green + a mutation-valid regression
# test was added. The ungameable core: completeTask must actually mutate the store + throw on an unknown id,
# and the new test must FAIL on the base src that lacks completeTask.
set -uo pipefail
ROOT="${CATALOG:-$PWD}"; W="$ROOT/taskflow"
[ -d "$W/.git" ] || { echo "FAIL: no taskflow repo at $W"; exit 1; }
BASE=$(git -C "$W" rev-list --max-parents=0 HEAD 2>/dev/null); fail=0

git -C "$W" grep -qE 'export (function|const) completeTask' HEAD -- src 2>/dev/null \
  && echo "PASS: completeTask is exported from src" || { echo "FAIL: completeTask not exported from src"; fail=1; }

BEHAVE=$(cd "$W" && node --input-type=module -e '
import { addTask, completeTask, listTasks } from "./src/tasks.js";
let ok = true;
try {
  const t = addTask("grade me");
  const done = completeTask(t.id);
  if (!done || done.id !== t.id || done.done !== true) ok = false;   // returns the updated, done task
  const stored = listTasks().find(x => x.id === t.id);
  if (!stored || stored.done !== true) ok = false;                   // the store actually mutated
  let threw = false; try { completeTask(987654321); } catch { threw = true; }
  if (!threw) ok = false;                                            // unknown id must throw
} catch (e) { console.error(String(e)); ok = false; }
console.log(ok ? "CORRECT" : "WRONG");
' 2>&1)
echo "$BEHAVE" | grep -qx CORRECT \
  && echo "PASS: completeTask BEHAVES (done id -> updated task marked done; unknown id -> throws; store mutated)" \
  || { echo "FAIL: completeTask behavior WRONG:"; echo "$BEHAVE" | sed 's/^/      /'; fail=1; }

( cd "$W" && node --test >/dev/null 2>&1 ) && echo "PASS: suite is GREEN on HEAD" || { echo "FAIL: suite is RED on HEAD"; fail=1; }

test_changed=$(git -C "$W" diff --name-only "$BASE"..HEAD 2>/dev/null | grep -E 'test|spec|\.test\.|\.spec\.' || true)
if [ -n "$test_changed" ]; then
  echo "PASS: test file(s) added/changed: $(echo "$test_changed" | tr '\n' ' ')"
  # mutation-valid: run the HEAD tests against the BASE src (which lacks completeTask) → must FAIL
  T=$(mktemp -d); git -C "$W" archive HEAD | tar -x -C "$T" 2>/dev/null
  git -C "$W" show "$BASE:src/tasks.js" > "$T/src/tasks.js" 2>/dev/null || true
  if ( cd "$T" && node --test >/dev/null 2>&1 ); then
    echo "  WARN: HEAD tests PASS on the base src too — the regression test may not exercise completeTask"
  else
    echo "PASS: regression is mutation-valid (the HEAD tests FAIL on the base src lacking completeTask)"
  fi
  rm -rf "$T"
else
  echo "FAIL: no test file added/changed (no regression test)"; fail=1
fi
exit "$fail"
