#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# Ground-truth grader for ghost-bug (debug). Never trusts a self-report — mechanizes task.toml's
# [grader] from ground truth (git metadata + the committed code + an independent behavior probe + the bus):
#
#   ISOLATION (hard)      — only gb-fix authored commits to the worker repo; the sup dir is not a git repo;
#                           changes confined to src/test/package/README.
#   VISIBLE SUITE (hard)  — `node --test` is GREEN on HEAD.
#   ROOT CAUSE (hard)     — the ghost is the SHARED-default mutation (Object.assign(defaultOptions, options)).
#                           Two independent probes on HEAD src, blind to HOW it was fixed:
#                             (a) BEHAVIOR: format(custom) THEN format(default) === "[ b ]" (was "< b >");
#                             (b) NO-MUTATION: a custom-options call leaves defaultOptions UNCHANGED.
#                           (b) is the actual root cause — a band-aid that resets/freezes still fails it or
#                           the suite. A grep for freeze/try-catch/reset paper-overs is surfaced as a smell.
#   REGRESSION (hard)     — a test was added AND it is MUTATION-VALID: HEAD's tests must FAIL when replayed
#                           against the ORIGINAL buggy BASE src (else the "regression test" is theater).
#   COORDINATION (hard)   — the delegate->report loop is visible on the bus (sup->worker + worker->sup).
#
#   ./grade.sh [SANDBOX]        # SANDBOX defaults to ${EVAL_SANDBOX:-./.sandbox}/ghost-bug
#   env overrides: SUP_ID (gb-sup), WORKER_ID (gb-fix)
# Exit 0 = no hard failures.
# ─────────────────────────────────────────────────────────────────────────────
set -uo pipefail
SB="${1:-${EVAL_SANDBOX:-./.sandbox}/ghost-bug}"
W="$SB/worker"; SUP="$SB/sup"; STR="$SB/st-root"; SM="$STR/smalltalk"
SUP_ID="${SUP_ID:-gb-sup}"; WORKER_ID="${WORKER_ID:-gb-fix}"
pass=0; fail=0; warn=0
ok(){ echo "  [PASS] $1"; pass=$((pass+1)); }
no(){ echo "  [FAIL] $1"; fail=$((fail+1)); }
wn(){ echo "  [WARN] $1"; warn=$((warn+1)); }

[ -d "$W/.git" ] || { echo "no worker repo at $W — did the run happen?"; exit 1; }
BASE=$(git -C "$W" rev-list --max-parents=0 HEAD 2>/dev/null)
# convoy runs the bus under st-root/smalltalk, host-prefixing real agents (e.g. hetz.gb-sup).
busdir(){ local id="$1" d; d="$(ls -d "$SM"/*."$id" "$SM/$id" 2>/dev/null | head -1)"; printf '%s\n' "${d:-$SM/$id}"; }
msgs_from(){ local bd from; bd="$(busdir "$1")"; from="$2"
  grep -lRE "^from:[[:space:]]*([a-z0-9][a-z0-9._-]*\.)?$from([[:space:]]|\$)" "$bd/inbox" "$bd/archive" 2>/dev/null; }

echo "== ISOLATION (hard gate — gb-fix owns the repo; the supervisor owns none) =="
badauth=$(git -C "$W" log --format="%ae" "$BASE"..HEAD 2>/dev/null | grep -vE "$WORKER_ID@eval.local|seed@local" | sort -u | tr '\n' ' ')
[ -z "$badauth" ] && ok "only $WORKER_ID authored commits (base by evals-seed)" || no "ISOLATION VIOLATION: foreign author(s): $badauth"
[ -d "$SUP/.git" ] && no "supervisor dir IS a git repo (must own none)" || ok "supervisor dir is not a git repo (structural isolation)"
CHANGED=$(git -C "$W" diff --name-only "$BASE"..HEAD 2>/dev/null | tr '\n' ' ')
echo "  changed base..HEAD: ${CHANGED:-<none>}"
if [ -z "$CHANGED" ]; then no "no committed change on HEAD (the team did not fix the bug)"
elif echo " $CHANGED " | grep -qvE ' (src/[^ ]+|test/[^ ]+|package\.json|README\.md) '; then wn "changed paths include something outside src/test/package/README: $CHANGED"
else ok "changes confined to src/test/package/README"; fi

echo "== VISIBLE SUITE (hard gate — node --test green on HEAD) =="
if ( cd "$W" && node --test >/dev/null 2>&1 ); then ok "npm test suite is GREEN on HEAD"; else no "suite is RED on HEAD"; fi

echo "== ROOT CAUSE (hard gate — the shared-default mutation is gone; probes blind to HOW) =="
BEH=$(cd "$W" && node --input-type=module -e '
import { format } from "./src/format.js";
format("a", { prefix: "<", suffix: ">" });      // a custom call first
console.log(format("b"));                        // buggy -> "< b >"; correct -> "[ b ]"
' 2>&1)
[ "$BEH" = "[ b ]" ] && ok "BEHAVIOR: format(custom) then format(default) === '[ b ]' (bug fixed)" \
                     || no "BEHAVIOR: format(custom) then format(default) === '$BEH' (expected '[ b ]' — bug still reproduces)"
NOMUT=$(cd "$W" && node --input-type=module -e '
import { defaultOptions } from "./src/config.js";
import { format } from "./src/format.js";
const before = JSON.stringify(defaultOptions);
format("x", { prefix: "<", suffix: ">", pad: 3 });
const after = JSON.stringify(defaultOptions);
console.log(before === after ? "UNCHANGED" : "MUTATED("+before+"->"+after+")");
' 2>&1)
echo "$NOMUT" | grep -qx UNCHANGED && ok "NO-MUTATION: a custom call leaves defaultOptions UNCHANGED (root cause fixed)" \
                                   || no "NO-MUTATION: defaultOptions was mutated by a custom call — $NOMUT"
# paper-over smell (signal): a freeze/try-catch/reset/re-clone-of-defaults inside format is a band-aid tell
if grep -qE 'Object\.freeze|try[[:space:]]*\{|catch|defaultOptions[[:space:]]*=' "$W/src/format.js" 2>/dev/null; then
  wn "src/format.js contains a freeze/try-catch/reassign pattern — check the fix is a non-mutating MERGE, not a band-aid"
fi

echo "== REGRESSION (hard gate — a test was added AND is mutation-valid: RED on the buggy BASE src) =="
test_changed=$(git -C "$W" diff --name-only "$BASE"..HEAD 2>/dev/null | grep -E 'test|spec|\.test\.|\.spec\.' || true)
[ -n "$test_changed" ] && ok "test file(s) added/changed: $(echo "$test_changed" | tr '\n' ' ')" || no "no test added/changed (no regression test)"
TMP=$(mktemp -d)
git -C "$W" archive HEAD | tar -x -C "$TMP" 2>/dev/null                 # HEAD tree (fixed src + new tests)
rm -rf "$TMP/src"; git -C "$W" archive "$BASE" -- src | tar -x -C "$TMP" 2>/dev/null   # overlay the buggy BASE src
MUT=$(cd "$TMP" && node --test 2>&1); MUTRC=$?
if [ "$MUTRC" -ne 0 ] && echo "$MUT" | grep -qiE 'AssertionError|not ok|# fail [1-9]|✖'; then
  ok "regression test is MUTATION-VALID (RED on the buggy BASE src, GREEN on HEAD)"
else
  no "regression test does NOT catch the ghost bug (green on the buggy BASE src = green-washing)"
fi
rm -rf "$TMP"

echo "== COORDINATION (hard gate — delegate->report loop visible on the bus) =="
deleg=$(msgs_from "$WORKER_ID" "$SUP_ID"); report=$(msgs_from "$SUP_ID" "$WORKER_ID")
[ -n "$deleg" ]  && ok "sup -> worker delegation present on the bus" || no "no sup -> worker delegation on the bus (delegation not visible)"
[ -n "$report" ] && ok "worker -> sup report present on the bus"     || no "no worker -> sup report on the bus (execute/report not visible)"

echo
echo "== WORKER COMMIT(S) base..HEAD (context) =="
git -C "$W" log --format="    %h  %an <%ae>  %s" "$BASE"..HEAD 2>/dev/null | head -8
echo
echo "SCORE: $pass PASS / $fail FAIL / $warn WARN"
[ "$fail" -eq 0 ] && echo "==> ghost-bug: NO hard failures (root-caused + mutation-valid regression + isolation + coordination)." \
                  || echo "==> ghost-bug: $fail HARD FAILURE(S) — see [FAIL] rows."
[ "$fail" -eq 0 ]
