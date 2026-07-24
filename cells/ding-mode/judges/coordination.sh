#!/usr/bin/env bash
# JUDGE: coordination over ding — the sup drained the seeded kick, delegated to dm.dev, dm.dev reported
# back, and the sup confirmed to the requester (the [DING] loop closed over the st2 bus, no MCP).
set -uo pipefail
ROOT="${CATALOG:-$PWD}"; SM="${ST_ROOT:-$ROOT/${STBUS:-smalltalk}}"
SUP_ID="${SUP_ID:-dm.sup}"; WORKER_ID="${WORKER_ID:-dm.dev}"; REQUESTER="${REQUESTER:-requester}"
busdir(){ local id="$1" d; d="$(ls -d "$SM"/*."$id" "$SM/$id" 2>/dev/null | head -1)"; printf '%s\n' "${d:-$SM/$id}"; }
msgs_from(){ local owner from; owner="$(busdir "$1")"; from="$2"; grep -lRE "^from:[[:space:]]*([a-z0-9][a-z0-9._-]*\.)?$from([[:space:]]|\$)" "$owner/inbox" "$owner/archive" 2>/dev/null; }
fail=0
deleg=$(msgs_from "$WORKER_ID" "$SUP_ID"); report=$(msgs_from "$SUP_ID" "$WORKER_ID"); conf=$(msgs_from "$REQUESTER" "$SUP_ID")
[ -n "$deleg" ]  && echo "PASS: sup -> dm.dev delegation on the bus" || { echo "FAIL: no sup -> dm.dev delegation on the bus"; fail=1; }
[ -n "$report" ] && echo "PASS: dm.dev -> sup report on the bus (the [DING] loop closed)" || { echo "FAIL: no dm.dev -> sup report on the bus"; fail=1; }
[ -n "$conf" ]   && echo "PASS: sup -> requester confirmation on the bus (loop closed)" || { echo "FAIL: no sup -> requester confirmation on the bus"; fail=1; }
exit "$fail"
