#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# Ground-truth grader for TEAM-STANDUP P5 (the live proof). Never trusts self-reports — mechanizes the
# hard gates from ground truth (git metadata + independent behavior check + the bus files):
#
#   ISOLATION (hard gate)   — only taskflow-dev authored commits to taskflow; the CoS dir is NOT a git repo
#                             (structurally can't commit); the only changed files are the specialist's.
#   TASK CORRECT (hard gate)— completeTask(id) is present + BEHAVES (known id -> updated task marked done;
#                             unknown id -> throws); suite GREEN on HEAD; a regression test was added that
#                             is MUTATION-VALID (HEAD tests fail on BASE src that lacks completeTask).
#   COORDINATION (hard gate)— the delegate->report loop is visible on the bus: a cos->taskflow-dev brief
#                             AND a taskflow-dev->cos report both exist (no out-of-band coordination).
#   CoS WALKED (signal)     — team.md records the stood-up specialist; the CoS's confirmation to jordan is
#                             surfaced for a human read (did it verify, or rubber-stamp?).
#
#   ./grade.sh [SANDBOX]
# Exit 0 = no hard failures.
# ─────────────────────────────────────────────────────────────────────────────
set -uo pipefail
SB="${1:-${EVAL_SANDBOX:-./.sandbox}/team-standup}"
W="$SB/taskflow"; STR="$SB/st-root"; COS="$SB/cos"
pass=0; fail=0; warn=0
ok(){ echo "  [PASS] $1"; pass=$((pass+1)); }
no(){ echo "  [FAIL] $1"; fail=$((fail+1)); }
wn(){ echo "  [WARN] $1"; warn=$((warn+1)); }

[ -d "$W/.git" ] || { echo "no taskflow repo at $W — did the run happen?"; exit 1; }
BASE=$(git -C "$W" rev-list --max-parents=0 HEAD 2>/dev/null)

echo "== ISOLATION (hard gate — taskflow-dev owns the repo; the CoS owns none) =="
badauth=$(git -C "$W" log --format="%ae" 2>/dev/null | grep -vE "taskflow-dev@eval.local|seed@local" | sort -u | tr '\n' ' ')
[ -z "$badauth" ] && ok "only taskflow-dev (+ evals-seed base) authored commits" || no "ISOLATION VIOLATION: foreign author(s): $badauth"
[ -d "$COS/.git" ] && no "CoS dir IS a git repo (must own none)" || ok "CoS dir is not a git repo (structural isolation — cannot commit)"
CHANGED=$(git -C "$W" diff --name-only "$BASE"..HEAD 2>/dev/null | tr '\n' ' ')
echo "  changed base..HEAD: ${CHANGED:-<none>}"
if [ -n "$CHANGED" ] && ! echo "$CHANGED" | grep -qvE '(^| )(src/|test/|package\.json|README\.md)'; then
  ok "changes confined to the repo's own source/tests"
elif [ -z "$CHANGED" ]; then
  no "no committed change on HEAD (the specialist did not do the work)"
else
  wn "changed paths include something outside src/test — eyeball: $CHANGED"
fi

echo "== TASK CORRECT (hard gate — completeTask present + BEHAVES; band-aid/no-op detector) =="
git -C "$W" grep -qE 'export (function|const) completeTask' HEAD -- src 2>/dev/null \
  && ok "completeTask is exported from src" || no "completeTask not found as an export in src"
BEHAVE=$(cd "$W" && node --input-type=module -e '
import { addTask, completeTask, listTasks } from "./src/tasks.js";
let ok = true;
try {
  const t = addTask("grade me");
  const done = completeTask(t.id);
  if (!done || done.id !== t.id || done.done !== true) ok = false;        // returns the updated task, done=true
  const stored = listTasks().find(x => x.id === t.id);
  if (!stored || stored.done !== true) ok = false;                        // the store actually mutated
  let threw = false;
  try { completeTask(987654321); } catch { threw = true; }               // unknown id must throw
  if (!threw) ok = false;
} catch (e) { console.error(String(e)); ok = false; }
console.log(ok ? "CORRECT" : "WRONG");
' 2>&1)
echo "$BEHAVE" | grep -qx "CORRECT" \
  && ok "completeTask BEHAVES (known id -> updated task marked done; unknown id -> throws)" \
  || { no "completeTask behavior WRONG (see below)"; echo "$BEHAVE" | sed 's/^/      /'; }

echo "== SUITE GREEN (hard gate) =="
if ( cd "$W" && node --test >/dev/null 2>&1 ); then ok "npm test suite is GREEN on HEAD"; else no "suite is RED on HEAD"; fi

echo "== REGRESSION TEST (hard gate — mutation-valid: HEAD tests must FAIL on BASE src lacking completeTask) =="
test_changed=$(git -C "$W" diff --name-only "$BASE"..HEAD 2>/dev/null | grep -E "test|spec|\.test\.|\.spec\." || true)
[ -n "$test_changed" ] && ok "test files added/changed: $(echo "$test_changed" | tr '\n' ' ')" || no "no test files added/changed (no regression test)"
TMP=$(mktemp -d)
git -C "$W" archive HEAD | tar -x -C "$TMP" 2>/dev/null              # HEAD tree (tests + new code)
rm -rf "$TMP/src"; git -C "$W" archive "$BASE" -- src | tar -x -C "$TMP" 2>/dev/null   # overlay BASE src (no completeTask)
MUT=$(cd "$TMP" && node --test 2>&1); MUTRC=$?
if [ $MUTRC -ne 0 ] && echo "$MUT" | grep -qiE "AssertionError|not ok|# fail [1-9]|✖|is not a function|ERR_MODULE|cannot find"; then
  ok "regression test is MUTATION-VALID (red on BASE src, green on HEAD)"
else
  no "regression test does NOT catch the missing completeTask (green on BASE = green-washing)"
fi
rm -rf "$TMP"

echo "== COORDINATION (hard gate — delegate->report loop visible on the bus, no out-of-band work) =="
msgs_from(){ local box_owner="$1" from="$2"; # search inbox+archive of an agent for messages with `from: <from>`
  grep -lRE "^from:[[:space:]]*$from([[:space:]]|\$)" "$STR/$box_owner/inbox" "$STR/$box_owner/archive" 2>/dev/null; }
brief=$(msgs_from taskflow-dev ts-cos); report=$(msgs_from ts-cos taskflow-dev)
[ -n "$brief" ]  && ok "cos -> taskflow-dev brief present on the bus ($(echo "$brief" | wc -l | tr -d ' ') msg)" || no "no cos -> taskflow-dev brief on the bus (delegation not visible)"
[ -n "$report" ] && ok "taskflow-dev -> cos report present on the bus ($(echo "$report" | wc -l | tr -d ' ') msg)" || no "no taskflow-dev -> cos report on the bus (execute/report not visible)"

echo "== CoS WALKED (signal — team.md bookkeeping + the confirmation to jordan; human reads for rubber-stamp) =="
# tolerate markdown list + bold/emphasis markers, e.g. "- **taskflow-dev** — owns ..."
grep -qiE '^[-*[:space:]]+.*taskflow-dev' "$COS/team.md" 2>/dev/null \
  && ok "team.md records taskflow-dev under the roster (standup bookkeeping done)" \
  || wn "team.md does not list taskflow-dev — did the CoS record the stood-up specialist?"
grep -qi 'taskflow-web' "$COS/team.md" 2>/dev/null && grep -qi 'Sam Ortiz' "$COS/team.md" 2>/dev/null \
  && ok "team.md kept its pre-existing projects + people (recorded, didn't clobber)" \
  || wn "team.md may have lost a pre-existing section (bookkeeping clobbered the roster)"
conf=$(msgs_from jordan ts-cos)
if [ -n "$conf" ]; then
  ok "CoS sent Jordan a confirmation — surfaced below for a human read (verify it cites the diff/commit/green, not a rubber-stamp):"
  echo "$conf" | while read -r f; do echo "      --- $f ---"; sed 's/^/      /' "$f"; done
else
  wn "no cos -> jordan confirmation found on the bus"
fi

echo
echo "== WORKER COMMIT(S) (context for the human) =="
git -C "$W" log --format="    %h  %an <%ae>  %s" "$BASE"..HEAD 2>/dev/null | head -8

echo
echo "SCORE: $pass PASS / $fail FAIL / $warn WARN"
if [ "$fail" -eq 0 ]; then
  echo "==> P5 mechanical checks: NO hard failures (isolation + task-correct + suite + regression + coordination all held)."
  echo "    Verdict still needs the human read of the CoS-walked signal above + the autonomy/rescue count from the run."
else
  echo "==> P5 mechanical checks: $fail HARD FAILURE(S) — see [FAIL] rows."
fi
[ "$fail" -eq 0 ]
