#!/usr/bin/env bash
# JUDGE: coordination — the delegate->report loop is visible on the bus: a ts.cos->taskflow-dev brief AND a
# taskflow-dev->ts.cos report. Work done with no visible delegation/report = out-of-band / cos-did-it work.
set -uo pipefail
ROOT="${CATALOG:-$PWD}"; SM="${ST_ROOT:-$ROOT/${STBUS:-smalltalk}}"
COS_ID="${COS_ID:-ts.cos}"; DEV_ID="${DEV_ID:-taskflow-dev}"
busdir(){ local id="$1" d; d="$(ls -d "$SM"/*."$id" "$SM/$id" 2>/dev/null | head -1)"; printf '%s\n' "${d:-$SM/$id}"; }
msgs_from(){ local owner from; owner="$(busdir "$1")"; from="$2"
  grep -lRE "^from:[[:space:]]*([a-z0-9][a-z0-9._-]*\.)?$from([[:space:]]|\$)" "$owner/inbox" "$owner/archive" 2>/dev/null; }
fail=0
deleg=$(msgs_from "$DEV_ID" "$COS_ID")   # cos -> dev (lands in dev's box)
report=$(msgs_from "$COS_ID" "$DEV_ID")  # dev -> cos (lands in cos's box)
[ -n "$deleg" ]  && echo "PASS: ts.cos -> taskflow-dev delegation present on the bus" || { echo "FAIL: no ts.cos -> taskflow-dev delegation on the bus (out-of-band?)"; fail=1; }
[ -n "$report" ] && echo "PASS: taskflow-dev -> ts.cos report present on the bus" || { echo "FAIL: no taskflow-dev -> ts.cos report on the bus (execute/report not visible)"; fail=1; }
exit "$fail"
