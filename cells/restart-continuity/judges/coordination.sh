#!/usr/bin/env bash
# JUDGE: coordination — the delegate->report loop is visible on the bus (and survives the restart): a
# rc.sup->rc.dev delegation and a rc.dev->rc.sup report. Work done with no visible delegation/report is the
# signature of out-of-band / sup-did-it-itself work.
# PASS (exit 0): both the delegation and the report are present on the bus.
set -uo pipefail
ROOT="${CATALOG:-$PWD}"
SM="${ST_ROOT:-$ROOT/${STBUS:-smalltalk}}"                    # bus root (st2 ding runs under $CATALOG/smalltalk)
SUP_ID="${SUP_ID:-rc.sup}"; WORKER_ID="${WORKER_ID:-rc.dev}"

busdir(){ local id="$1" d; d="$(ls -d "$SM"/*."$id" "$SM/$id" 2>/dev/null | head -1)"; printf '%s\n' "${d:-$SM/$id}"; }
msgs_from(){ local owner from; owner="$(busdir "$1")"; from="$2"
  grep -lRE "^from:[[:space:]]*([a-z0-9][a-z0-9._-]*\.)?$from([[:space:]]|\$)" "$owner/inbox" "$owner/archive" 2>/dev/null; }

fail=0
deleg=$(msgs_from "$WORKER_ID" "$SUP_ID")   # sup -> worker (lands in the worker's box)
report=$(msgs_from "$SUP_ID" "$WORKER_ID")  # worker -> sup (lands in the sup's box)
[ -n "$deleg" ]  && echo "PASS: rc.sup -> rc.dev delegation present on the bus" \
                 || { echo "FAIL: no rc.sup -> rc.dev delegation on the bus (delegation not visible)"; fail=1; }
[ -n "$report" ] && echo "PASS: rc.dev -> rc.sup report present on the bus" \
                 || { echo "FAIL: no rc.dev -> rc.sup report on the bus (execute/report not visible)"; fail=1; }
exit "$fail"
