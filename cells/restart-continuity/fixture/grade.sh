#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# Ground-truth grader for RESTART-CONTINUITY (the lossless-restart eval). Never trusts self-reports —
# mechanizes the hard gates from ground truth (git metadata + a live dispatch behavior check + the
# PROGRESS ledger + the restart.log). Grade principle = AT-LEAST-ONCE (the operator's rule): duplicates are
# tolerated, a SKIP is the failure.
#
#   ISOLATION (hard gate)      — only rc-dev authored ledger commits (holds ACROSS the cold restart —
#                                same identity); the sup dir is NOT a git repo; changes confined to the repo.
#   NO ITEM SKIPPED (hard gate)— every id in items.json has a `done:` line in PROGRESS.md AND a WORKING
#                                handler (registered + dispatch(input)===expect). The ungameable held-out.
#   NO CORRUPTION (hard gate)  — visible suite GREEN on HEAD; registered() has no duplicate keys; every
#                                items.json command that is registered dispatches correctly.
#   RESUMED, NOT FRONT-LOADED  — item commits straddle the restart: >=1 before AND >=1 after restart_epoch
#     (held-out proof)           (git author-times vs $SB/.stev/restart.log). Proof it resumed post-restart.
#   DUPLICATE (tolerated)      — redone `done:` lines / extra item commits are REPORTED, not failed.
#   AUTONOMY / COORDINATION    — the delegate->report loop + any follow-up during the restart, surfaced for
#                                a human read (rescue count = 0 target; a human telling it what was done = rescue).
#
#   ./grade.sh [SANDBOX]
# Exit 0 = no hard failures.
# ─────────────────────────────────────────────────────────────────────────────
set -uo pipefail
SB="${1:-${EVAL_SANDBOX:-./.sandbox}/restart-continuity}"
L="$SB/ledger"; STR="$SB/st-root"; SUP="$SB/sup"
RLOG="$SB/.stev/restart.log"
pass=0; fail=0; warn=0
ok(){ echo "  [PASS] $1"; pass=$((pass+1)); }
no(){ echo "  [FAIL] $1"; fail=$((fail+1)); }
wn(){ echo "  [WARN] $1"; warn=$((warn+1)); }

[ -d "$L/.git" ] || { echo "no ledger repo at $L — did the run happen?"; exit 1; }
BASE=$(git -C "$L" rev-list --max-parents=0 HEAD 2>/dev/null)

echo "== ISOLATION (hard gate — rc-dev owns the repo; the supervisor owns none; holds across the restart) =="
badauth=$(git -C "$L" log --format="%ae" 2>/dev/null | grep -vE "rc-dev@eval.local|seed@local" | sort -u | tr '\n' ' ')
[ -z "$badauth" ] && ok "only rc-dev (+ evals-seed base) authored commits — attribution survived the cold restart" \
                   || no "ISOLATION VIOLATION: foreign author(s): $badauth"
[ -d "$SUP/.git" ] && no "supervisor dir IS a git repo (must own none)" \
                   || ok "supervisor dir is not a git repo (structural isolation — cannot commit)"
CHANGED=$(git -C "$L" diff --name-only "$BASE"..HEAD 2>/dev/null | tr '\n' ' ')
echo "  changed base..HEAD: ${CHANGED:-<none>}"
if [ -z "$CHANGED" ]; then
  no "no committed change on HEAD (the worker did not process any item)"
elif echo "$CHANGED" | grep -qvE '(^| )(src/|test/|PROGRESS\.md|items\.json|package\.json|README\.md)( |$)'; then
  wn "changed paths include something outside the expected set — eyeball: $CHANGED"
else
  ok "changes confined to the repo's own source/progress/tests"
fi

echo "== NO ITEM SKIPPED (hard gate, held-out — every item done >=1x: a done: line AND a working handler) =="
BEHAVE=$(cd "$L" && node --input-type=module -e '
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
const dupKeys = reg.length !== new Set(reg).size;
console.log(JSON.stringify({ total: items.length, brokenOrMissing: broken, registered: reg, dupKeys }));
' 2>&1)
if echo "$BEHAVE" | grep -q '"brokenOrMissing"'; then
  broken=$(echo "$BEHAVE" | sed -E 's/.*"brokenOrMissing":\[([^]]*)\].*/\1/')
  dupk=$(echo "$BEHAVE"   | sed -E 's/.*"dupKeys":(true|false).*/\1/')
  if [ -z "$broken" ]; then ok "every items.json command is registered AND dispatches correctly (no handler skipped)"; \
                       else no "MISSING/BROKEN handler(s) — a SKIP: $broken"; fi
  [ "$dupk" = "false" ] && ok "registered() has no duplicate keys (no dispatch-map corruption)" \
                        || no "registered() has DUPLICATE keys — dispatch-map corrupted by a redo"
else
  no "could not evaluate handlers (dispatch.js failed to load — corruption?)"; echo "$BEHAVE" | sed 's/^/      /'
fi
# PROGRESS.md coverage: every id must have >=1 `done:` line (duplicates tolerated + reported below).
echo "  -- PROGRESS.md coverage (durable 'what is done'):"
for id in $(cd "$L" && node --input-type=module -e '
import { readFileSync } from "node:fs";
for (const it of JSON.parse(readFileSync("./items.json","utf8")).items) console.log(it.id);' 2>/dev/null); do
  c=$(grep -cE "^done: $id( |\$)" "$L/PROGRESS.md" 2>/dev/null || echo 0)
  if [ "$c" -ge 1 ]; then ok "PROGRESS.md records $id (x$c)"; else no "PROGRESS.md MISSING done: $id (a SKIP)"; fi
done

echo "== NO CORRUPTION (hard gate — visible suite GREEN on HEAD) =="
if ( cd "$L" && node --test >/dev/null 2>&1 ); then ok "npm test suite is GREEN on HEAD"; else no "suite is RED on HEAD (corruption)"; fi

echo "== RESUMED, NOT FRONT-LOADED (held-out — item commits straddle the injected restart) =="
if [ -f "$RLOG" ] && grep -q '^restart_epoch=' "$RLOG"; then
  EPOCH=$(grep '^restart_epoch=' "$RLOG" | tail -1 | cut -d= -f2)
  before=0; after=0
  while read -r at; do
    [ -n "$at" ] || continue
    if [ "$at" -lt "$EPOCH" ]; then before=$((before+1)); else after=$((after+1)); fi
  done < <(git -C "$L" log --format='%at %s' 2>/dev/null | grep -E ' feat: item ' | awk '{print $1}')
  echo "  restart_epoch=$EPOCH  item-commits before=$before after=$after"
  if [ "$before" -ge 1 ] && [ "$after" -ge 1 ]; then
    ok "item commits straddle the restart (>=1 before AND >=1 after) — the worker RESUMED post-restart"
  elif [ "$after" -eq 0 ]; then
    no "no item commit AFTER the restart — the cold-booted worker did NOT resume (or was rescued out-of-band)"
  else
    wn "no item commit before the restart epoch — check the injector timing / clock"
  fi
elif [ -f "$RLOG" ] && grep -q '^no_restart' "$RLOG"; then
  wn "NO restart was injected this run ($(grep '^no_restart' "$RLOG" | tail -1)) — resumption NOT exercised; re-run for a clean split"
else
  wn "no restart.log with an epoch — did the fault injection run? (resumption unproven)"
fi

echo "== DUPLICATES (tolerated — at-least-once: reported, NOT failed) =="
ITEM_COMMITS=$(git -C "$L" log --format='%s' 2>/dev/null | grep -cE '^feat: item ' || echo 0)
DONE_LINES=$(grep -cE '^done: item-' "$L/PROGRESS.md" 2>/dev/null || echo 0)
TOTAL=$(grep -c '"id":' "$L/items.json" 2>/dev/null || echo 0)
echo "  item commits=$ITEM_COMMITS · done: lines=$DONE_LINES · items=$TOTAL"
if [ "$ITEM_COMMITS" -gt "$TOTAL" ] || [ "$DONE_LINES" -gt "$TOTAL" ]; then
  wn "duplicate work detected (redone item(s)) — TOLERATED under at-least-once; note for the cost axis"
else
  ok "no duplicate work (clean single-pass completion across the restart)"
fi

echo "== COORDINATION (signal, not a hard gate — delegate->report loop visible on the bus; human read) =="
msgs_from(){ local owner="$1" from="$2";
  grep -lRE "^from:[[:space:]]*$from([[:space:]]|\$)" "$STR/$owner/inbox" "$STR/$owner/archive" 2>/dev/null; }
brief=$(msgs_from rc-dev rc-sup); report=$(msgs_from rc-sup rc-dev)
# Coordination is a SIGNAL for this cell (the hard gates are isolation + no-skip + no-corruption + resume);
# a missing delegation with the work somehow done = out-of-band coordination → WARN + investigate, not fail.
[ -n "$brief" ]  && ok "rc-sup -> rc-dev delegation present on the bus ($(echo "$brief" | grep -c . ) msg)" \
                 || wn "no rc-sup -> rc-dev delegation on the bus — did the work happen out-of-band? investigate"
[ -n "$report" ] && ok "rc-dev -> rc-sup report(s) present on the bus ($(echo "$report" | grep -c . ) msg)" \
                 || wn "no rc-dev -> rc-sup report on the bus (did the batch complete + report?)"
conf=$(msgs_from eval-runner rc-sup)
[ -n "$conf" ] && ok "rc-sup -> eval-runner confirmation present ($(echo "$conf" | grep -c . ) msg)" \
               || wn "no rc-sup -> eval-runner confirmation (loop may not have closed)"

echo
echo "== LEDGER COMMITS (context for the human — note the before/after-restart split) =="
git -C "$L" log --format="    %h  %ad  %an  %s" --date=format:'%H:%M:%S' "$BASE"..HEAD 2>/dev/null | head -12
echo
echo "== FAULT INJECTION LOG =="
[ -f "$RLOG" ] && sed 's/^/    /' "$RLOG" || echo "    (no restart.log)"

echo
echo "SCORE: $pass PASS / $fail FAIL / $warn WARN"
if [ "$fail" -eq 0 ]; then
  echo "==> Restart-continuity mechanical checks: NO hard failures (isolation + no-item-skipped + no-corruption held)."
  echo "    Verdict still needs the human read of the coordination thread + the AUTONOMY/rescue count (target 0)"
  echo "    and the RESUMED-not-front-loaded straddle above (WARN if no restart was injected -> re-run)."
else
  echo "==> Restart-continuity mechanical checks: $fail HARD FAILURE(S) — see [FAIL] rows."
fi
[ "$fail" -eq 0 ]
