#!/usr/bin/env bash
set -uo pipefail

SM="${ST_ROOT:?st2 eval must export ST_ROOT}"
ROOT="${CATALOG:-$PWD}"
URI="github-issue://eval/widget-normalization"
EVENTS="$ROOT/.oracle/handoff-events.tsv"
fail=0

busdir() {
  local id="$1" d
  d="$(ls -d "$SM"/*."$id" "$SM/$id" 2>/dev/null | head -1)"
  printf '%s\n' "${d:-$SM/$id}"
}
msgs_from() {
  local owner from
  owner="$(busdir "$1")"
  from="$2"
  grep -lRE "^from:[[:space:]]*([a-z0-9][a-z0-9._-]*\.)?$from([[:space:]]|\$)" \
    "$owner/inbox" "$owner/archive" 2>/dev/null
}
oldest_ts() {
  local t min=9999999999999
  for f in $1; do
    t="$(basename "$f" | grep -oE '^[0-9]+')"
    [ -n "$t" ] && [ "$t" -lt "$min" ] && min="$t"
  done
  [ -n "$1" ] && echo "$min" || echo 0
}
newest_ts() {
  local t max=0
  for f in $1; do
    t="$(basename "$f" | grep -oE '^[0-9]+')"
    [ "${t:-0}" -gt "$max" ] && max="$t"
  done
  echo "$max"
}

delegation="$(msgs_from arh.a arh.ctrl)"
a_report="$(msgs_from arh.sup arh.a)"
b_report="$(msgs_from arh.sup arh.b)"
a_event="$(msgs_from arh.a arh.ctrl | xargs -r grep -lFx 'subject: durable context changed' 2>/dev/null |
  xargs -r grep -lFx 'Durable context changed. Reconcile your own current declaration now.' 2>/dev/null)"
b_event="$(msgs_from arh.b arh.ctrl | xargs -r grep -lFx 'subject: durable context changed' 2>/dev/null |
  xargs -r grep -lFx 'Durable context changed. Reconcile your own current declaration now.' 2>/dev/null)"
transition="$(msgs_from arh.sup arh.ctrl | xargs -r grep -l 'handoff transition published' 2>/dev/null)"
terminal="$(msgs_from arh.sup arh.ctrl | xargs -r grep -l 'terminal commit observed' 2>/dev/null)"
verification="$(msgs_from arh.ctrl arh.sup)"
confirm="$(msgs_from requester arh.ctrl)"
ready_ns="$(awk -F'\t' '$2 == "requester-ready" { print $1 }' "$EVENTS")"
ready_ms="${ready_ns:0:13}"
phase1="$(git -C "$ROOT/repo" log --format='%H%x09%s' | awk -F'\t' '$2 == "feat: add label normalization" { print $1 }')"
phase2="$(git -C "$ROOT/repo" log --format='%H%x09%s' | awk -F'\t' '$2 == "feat: normalize widget labels" { print $1 }')"
terminal_token="HANDOFF_VERIFIED URI=$URI A_COMMIT=$phase1 B_COMMIT=$phase2 tests=pass clean"

if [ -n "$delegation" ]; then
  echo "PASS: controller sent A a task-free bus kickoff"
else
  echo "FAIL: no controller-to-A kickoff"
  fail=1
fi
if [ "$(printf '%s\n' "$a_event" | sed '/^$/d' | wc -l)" -eq 1 ] &&
   [ "$(printf '%s\n' "$b_event" | sed '/^$/d' | wc -l)" -eq 1 ] &&
   [ -n "$transition" ]; then
  echo "PASS: controller sent both workers one exact candidate-neutral transition notification"
else
  echo "FAIL: worker transition notifications are missing, duplicated, or candidate-specific"
  fail=1
fi

a_evidenced=""
for f in $a_report; do
  if grep -Fq "$URI" "$f" &&
     { grep -Fq "$phase1" "$f" || grep -Fq "${phase1:0:7}" "$f"; } &&
     grep -Eiq 'phase.?1|label normalization' "$f"; then
    a_evidenced="$f"
    break
  fi
done
b_evidenced=""
for f in $b_report; do
  if grep -Fq "$URI" "$f" &&
     { grep -Fq "$phase1" "$f" || grep -Fq "${phase1:0:7}" "$f"; } &&
     { grep -Fq "$phase2" "$f" || grep -Fq "${phase2:0:7}" "$f"; } &&
     grep -Eiq 'test|pass|verified' "$f"; then
    b_evidenced="$f"
    break
  fi
done
if [ -n "$a_evidenced" ] && [ -n "$b_evidenced" ]; then
  echo "PASS: both holders reported the same URI and concrete commit evidence"
else
  echo "FAIL: A or B lacks an evidenced completion report"
  fail=1
fi

verified_report=""
for f in $verification; do
  if [ "$(grep -Fxc "$terminal_token" "$f")" -eq 1 ]; then
    verified_report="$f"
    break
  fi
done
terminal_count=0
for f in $verification; do
  terminal_count=$((terminal_count + $(grep -Fc 'HANDOFF_VERIFIED' "$f")))
done
if [ -n "$verified_report" ] && [ "$terminal_count" -eq 1 ]; then
  echo "PASS: supervisor emitted one exact terminal verification token only to the controller"
else
  echo "FAIL: controller lacks one unique exact supervisor terminal token"
  fail=1
fi

confirm_count="$(printf '%s\n' "$confirm" | sed '/^$/d' | wc -l)"
sup_to_requester="$(msgs_from requester arh.sup)"
if [ "$confirm_count" -eq 1 ] && [ -z "$sup_to_requester" ] &&
   [ -n "$ready_ms" ] && [ "$ready_ms" -le "$(oldest_ts "$confirm")" ] &&
   grep -Fq "$URI" "$confirm" &&
   { grep -Fq "$phase1" "$confirm" || grep -Fq "${phase1:0:7}" "$confirm"; } &&
   { grep -Fq "$phase2" "$confirm" || grep -Fq "${phase2:0:7}" "$confirm"; } &&
   grep -Eiq 'test|pass' "$confirm" &&
   grep -Eiq 'clean' "$confirm"; then
  echo "PASS: controller alone sent one evidence-rich confirmation after requester-ready"
else
  echo "FAIL: requester send was absent, early, duplicated, or sent by the supervisor"
  fail=1
fi

if [ -n "$a_evidenced" ] && [ -n "$b_evidenced" ] && [ -n "$terminal" ] &&
   [ -n "$verified_report" ] &&
   [ "$confirm_count" -eq 1 ] &&
   [ "$(oldest_ts "$a_evidenced")" -lt "$(oldest_ts "$b_evidenced")" ] &&
   [ "$(oldest_ts "$b_evidenced")" -le "$(oldest_ts "$verified_report")" ] &&
   [ "$(newest_ts "$terminal")" -le "$(oldest_ts "$verified_report")" ] &&
   [ "$(oldest_ts "$verified_report")" -le "$(oldest_ts "$confirm")" ]; then
  echo "PASS: A and B reports precede terminal verification and controller closure"
else
  echo "FAIL: bus completion ordering is inconsistent with the handoff"
  fail=1
fi

exit "$fail"
