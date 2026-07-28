#!/usr/bin/env bash
# JUDGE: coordination — the whole loop is visible on the bus: the supervisor delegated to the seat it stood
# up, that seat reported back, and the supervisor closed the loop to the requester. A finished repo with no
# delegation and no report is the signature of a supervisor that did the work itself.
#
# PASS (exit 0): a ts.cos -> specialist delegation, a specialist -> ts.cos report, and a ts.cos -> requester
# confirmation are all present.
set -uo pipefail
SM="${ST_ROOT:-${CATALOG:-$PWD}}"
SUP_ID="${SUP_ID:-ts.cos}"; REQ_ID="${REQ_ID:-requester}"

# Resolve an id to its on-disk bus dir, tolerating a leading team/host prefix.
busdir() { local id="$1" d; d="$(ls -d "$SM"/*."$id" "$SM/$id" 2>/dev/null | head -1)"; printf '%s\n' "${d:-$SM/$id}"; }
msgs_from() { local owner from; owner="$(busdir "$1")"; from="$2"
  grep -lRE "^from:[[:space:]]*([a-z0-9][a-z0-9._-]*\.)?${from}([[:space:]]|\$)" \
    "$owner/inbox" "$owner/archive" 2>/dev/null; }

fail=0

# The specialist's own box: whichever identity the supervisor seated, it is not the supervisor or requester.
spec_boxes="$(find "$SM" -mindepth 1 -maxdepth 1 -type d \
  ! -name "*${SUP_ID##*.}" ! -name "*${REQ_ID}" ! -name 'logs' ! -name 'exec' ! -name 'state' \
  ! -name 'pty' ! -name 'cos' ! -name 'widget' ! -name '.runs' 2>/dev/null)"
deleg=""
for box in $spec_boxes; do
  found="$(grep -lRE "^from:[[:space:]]*([a-z0-9][a-z0-9._-]*\.)?${SUP_ID##*.}([[:space:]]|\$)" \
    "$box/inbox" "$box/archive" 2>/dev/null || true)"
  [ -n "$found" ] && deleg="$deleg $found"
done
[ -n "${deleg// /}" ] && echo "PASS: supervisor -> specialist delegation present on the bus" \
                      || { echo "FAIL: no supervisor -> specialist delegation on the bus"; fail=1; }

# The report back: mail in the supervisor's box from someone who is neither the supervisor nor the requester.
sup_box="$(busdir "$SUP_ID")"
report="$(grep -rhsE '^from:[[:space:]]*[A-Za-z0-9]' "$sup_box/inbox" "$sup_box/archive" 2>/dev/null |
  sed -E 's/^from:[[:space:]]*//; s/[[:space:]]+$//' |
  grep -vE "^([a-z0-9][a-z0-9._-]*\.)?(${SUP_ID##*.}|${REQ_ID})\$" | sort -u || true)"
[ -n "$report" ] && echo "PASS: specialist -> supervisor report present on the bus (from: $(printf '%s' "$report" | tr '\n' ' '))" \
                 || { echo "FAIL: no specialist -> supervisor report on the bus"; fail=1; }

# The loop closes: the requester hears from the supervisor.
confirm="$(msgs_from "$REQ_ID" "${SUP_ID##*.}")"
[ -n "$confirm" ] && echo "PASS: supervisor -> requester confirmation present on the bus" \
                  || { echo "FAIL: the requester never heard back from the supervisor"; fail=1; }

exit "$fail"
