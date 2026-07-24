#!/usr/bin/env bash
# JUDGE: recommendation — a justified recommendation reached the requester on the bus (fd.sup -> requester).
set -uo pipefail
ROOT="${CATALOG:-$PWD}"; SM="${ST_ROOT:-$ROOT/${STBUS:-smalltalk}}"
SUP_ID="${SUP_ID:-fd.sup}"; REQUESTER="${REQUESTER:-requester}"
busdir(){ local id="$1" d; d="$(ls -d "$SM"/*."$id" "$SM/$id" 2>/dev/null | head -1)"; printf '%s\n' "${d:-$SM/$id}"; }
owner="$(busdir "$REQUESTER")"
if grep -lRE "^from:[[:space:]]*([a-z0-9._-]+\.)?$SUP_ID([[:space:]]|\$)" "$owner/inbox" "$owner/archive" 2>/dev/null | grep -q .; then
  echo "PASS: fd.sup -> requester recommendation present on the bus"; exit 0
else
  echo "FAIL: no fd.sup -> requester recommendation on the bus (the panel never handed back a call)"; exit 1
fi
