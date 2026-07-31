#!/usr/bin/env bash
set -uo pipefail

ROOT="${CATALOG:-$PWD}"
SM="${ST_ROOT:?st2 eval must export ST_ROOT}"
W="$ROOT/worker"
A_URI="github-issue://eval/names-normalize"
B_URI="github-issue://eval/names-format-label"
fail=0

busdir() {
  local id="$1" d=""
  d="$(ls -d "$SM"/*."$id" "$SM/$id" 2>/dev/null | head -1 || true)"
  printf '%s\n' "${d:-$SM/$id}"
}

files_from() {
  local owner from
  owner="$(busdir "$1")"
  from="$2"
  grep -lRE "^from:[[:space:]]*$from([[:space:]]|$)" \
    "$owner/inbox" "$owner/archive" 2>/dev/null || true
}

oldest_ts() {
  local input="$1" f ts min=999999999999999
  for f in $input; do
    ts="$(basename "$f" | grep -oE '^[0-9]+' || true)"
    [ -n "$ts" ] && [ "$ts" -lt "$min" ] && min="$ts"
  done
  [ "$min" -eq 999999999999999 ] && echo 0 || echo "$min"
}

newest_ts() {
  local input="$1" f ts max=0
  for f in $input; do
    ts="$(basename "$f" | grep -oE '^[0-9]+' || true)"
    [ -n "$ts" ] && [ "$ts" -gt "$max" ] && max="$ts"
  done
  echo "$max"
}

sup_from_worker=$(files_from "ahr.sup" "ahr.worker")
worker_from_sup=$(files_from "ahr.worker" "ahr.sup")
worker_from_ctl=$(files_from "ahr.worker" "ahr.controller")
controller_from_sup=$(files_from "ahr.controller" "ahr.sup")
requester_from_ctl=$(files_from "requester" "ahr.controller")
requester_from_sup=$(files_from "requester" "ahr.sup")

a_report=$(printf '%s\n' "$sup_from_worker" | xargs -r grep -lF "RESOURCE_DONE uri=$A_URI" 2>/dev/null || true)
b_report=$(printf '%s\n' "$sup_from_worker" | xargs -r grep -lF "RESOURCE_DONE uri=$B_URI" 2>/dev/null || true)
idle_report=$(printf '%s\n' "$sup_from_worker" | xargs -r grep -lF "RESOURCE_IDLE" 2>/dev/null || true)

sup_to_worker_count=$(printf '%s\n' "$worker_from_sup" | sed '/^$/d' | wc -l)
if [ "$sup_to_worker_count" -ge 1 ] &&
   ! xargs -r grep -Eiq 'normalize|format-label|format label|formatlabel|reverse|joinNames' <<<"$worker_from_sup" &&
   [ "$(oldest_ts "$worker_from_sup")" -lt "$(oldest_ts "$a_report")" ] &&
   [ "$(printf '%s\n' "$worker_from_ctl" | sed '/^$/d' | wc -l)" -eq 2 ]; then
  echo "PASS: bus contains generic supervisor guidance and exactly two resource-change notifications"
else
  echo "FAIL: supervisor guidance leaked task facts, was absent, or controller notification count was wrong"
  fail=1
fi

if [ -n "$a_report" ] && [ -n "$b_report" ] && [ -n "$idle_report" ] &&
   [ "$(oldest_ts "$a_report")" -lt "$(oldest_ts "$b_report")" ] &&
   [ "$(oldest_ts "$b_report")" -lt "$(oldest_ts "$idle_report")" ]; then
  echo "PASS: worker reports exact A, then B, then idle ordering"
else
  echo "FAIL: worker A/B/idle reports are absent or out of order"
  fail=1
fi

confirm_count=$(printf '%s\n' "$requester_from_ctl" | sed '/^$/d' | wc -l)
head=$(git -C "$W" rev-parse HEAD)
if [ "$confirm_count" -eq 1 ] &&
   [ "$(printf '%s\n' "$controller_from_sup" | sed '/^$/d' | wc -l)" -eq 1 ] &&
   [ -z "$requester_from_sup" ] &&
   [ "$(newest_ts "$controller_from_sup")" -gt "$(newest_ts "$idle_report")" ] &&
   [ "$(newest_ts "$requester_from_ctl")" -gt "$(newest_ts "$controller_from_sup")" ] &&
   grep -Fq "HOT_RESOURCE_VERIFIED" "$controller_from_sup" &&
   grep -Fq "$A_URI" "$requester_from_ctl" &&
   grep -Fq "$B_URI" "$requester_from_ctl" &&
   grep -Fq "RESOURCE_IDLE" "$requester_from_ctl" &&
   grep -Fq "$head" "$requester_from_ctl"; then
  echo "PASS: supervisor reports evidence to controller after idle; controller closes exactly once"
else
  echo "FAIL: final evidence/control ordering is premature, duplicated, or lacks durable evidence"
  fail=1
fi

for id in ahr.sup ahr.worker ahr.controller; do
  inbox="$(busdir "$id")/inbox"
  unread=$(ls "$inbox"/*.md 2>/dev/null | wc -l)
  if [ "$unread" -eq 0 ]; then
    echo "PASS: $id inbox is clean"
  else
    echo "FAIL: $id has $unread unread bus message(s)"
    fail=1
  fi
done

exit "$fail"
