#!/usr/bin/env bash
set -uo pipefail

SM="${ST_ROOT:?st2 eval must export ST_ROOT}"
ROOT="${CATALOG:-$PWD}"
SUP_ID="${SUP_ID:-arc.sup}"
WORKER_ID="${WORKER_ID:-arc.worker}"
REQUESTER="${REQUESTER:-requester}"
WORK_URI="github-issue://eval/widget-license-mit"

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
newest_ts() {
  local t max=0
  for f in $1; do
    t="$(basename "$f" | grep -oE '^[0-9]+')"
    [ "${t:-0}" -gt "$max" ] && max="$t"
  done
  echo "$max"
}
oldest_ts() {
  local t min=9999999999999
  for f in $1; do
    t="$(basename "$f" | grep -oE '^[0-9]+')"
    [ -n "$t" ] && [ "$t" -lt "$min" ] && min="$t"
  done
  [ -n "$1" ] && echo "$min" || echo 0
}

fail=0
deleg=$(msgs_from "$WORKER_ID" "$SUP_ID")
report=$(msgs_from "$SUP_ID" "$WORKER_ID")
confirm=$(msgs_from "$REQUESTER" "$SUP_ID")
head=$(git -C "$ROOT/worker" rev-parse HEAD 2>/dev/null || true)
short_head=$(git -C "$ROOT/worker" rev-parse --short HEAD 2>/dev/null || true)
confirm_count=$(printf '%s\n' "$confirm" | sed '/^$/d' | wc -l)
evidenced_report=""
for f in $report; do
  if [ -n "$head" ] &&
     grep -Fq "$WORK_URI" "$f" &&
     { grep -Fq "$head" "$f" || grep -Fq "$short_head" "$f"; } &&
     grep -Fq "LICENSE" "$f" &&
     grep -Fq "package.json" "$f" &&
     grep -Eiq 'complet|done|verified|pass' "$f" &&
     ! grep -Eiq 'block|fail|could not|unable|error' "$f"; then
    evidenced_report="$f"
    break
  fi
done

if [ -n "$deleg" ]; then
  echo "PASS: supervisor delegated over the bus"
else
  echo "FAIL: no supervisor-to-worker delegation"
  fail=1
fi
if [ -n "$evidenced_report" ]; then
  echo "PASS: worker reported the exact URI, commit, changed files, and verification"
else
  echo "FAIL: no evidenced worker-to-supervisor completion report"
  fail=1
fi
if [ "$confirm_count" -eq 1 ] && [ -n "$evidenced_report" ] &&
   [ "$(newest_ts "$confirm")" -gt "$(oldest_ts "$evidenced_report")" ]; then
  echo "PASS: exactly one supervisor completion post-dates the evidenced worker report"
else
  echo "FAIL: expected exactly one post-report supervisor completion"
  fail=1
fi
if [ "$confirm_count" -eq 1 ] && [ -n "$head" ] &&
   grep -Fq "$WORK_URI" "$confirm" &&
   { grep -Fq "$head" "$confirm" || grep -Fq "$short_head" "$confirm"; } &&
   grep -Fq "LICENSE" "$confirm" &&
   grep -Fq "package.json" "$confirm" &&
   grep -Eiq 'complet|done|verified|pass' "$confirm" &&
   ! grep -Eiq 'block|fail|could not|unable|error' "$confirm"; then
  echo "PASS: supervisor completion cites the URI, actual commit, and concrete verification"
else
  echo "FAIL: supervisor completion lacks the URI, actual commit, or verification evidence"
  fail=1
fi

exit "$fail"
