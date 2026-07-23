#!/usr/bin/env bash
# JUDGE: the THREADED reply path — dr.agent replied to dr-req's kick via `st2 message reply` (in-reply-to the
# kick), carrying the ANSWER.txt token. A plain `st2 message send` (no in-reply-to) does NOT pass — the exact
# gap this cell covers.
set -uo pipefail
ROOT="${CATALOG:-$PWD}"; SM="${ST_ROOT:-$ROOT/${STBUS:-smalltalk}}"
AGENT="${AGENT:-dr.agent}"; REQ="${REQ:-dr-req}"
TOKEN="$(tr -d '\r\n' < "$ROOT/work/ANSWER.txt" 2>/dev/null)"
busdir(){ local id="$1" d; d="$(ls -d "$SM"/*."$id" "$SM/$id" 2>/dev/null | head -1)"; printf '%s\n' "${d:-$SM/$id}"; }
pfrom(){ printf '^from:[[:space:]]*([a-z0-9][a-z0-9._-]*\.)?%s([[:space:]]|$)' "$1"; }
fail=0
REQBOX="$(busdir "$REQ")"
reply="$(grep -lRE "$(pfrom "$AGENT")" "$REQBOX/inbox" "$REQBOX/archive" 2>/dev/null | head -1)"
if [ -z "$reply" ]; then
  echo "FAIL: no reply from $AGENT in $REQ's inbox — the agent never replied over the bus (st2 message reply missing/broken?)"; exit 1
fi
echo "PASS: a reply from $AGENT landed in $REQ's inbox ($(basename "$reply"))"
irt="$(grep -E '^in-reply-to:' "$reply" 2>/dev/null | head -1 | sed 's/^in-reply-to:[[:space:]]*//')"
if [ -n "$irt" ]; then echo "PASS: the reply is THREADED — in-reply-to: $irt (proves st2 message reply, not a fresh send)"
else echo "FAIL: the reply has NO in-reply-to — a plain st2 message send, NOT the threaded reply (the exact bug case)"; fail=1; fi
if [ -n "$TOKEN" ] && grep -qF "$TOKEN" "$reply"; then echo "PASS: the reply body carries the ANSWER.txt token ($TOKEN)"
else echo "FAIL: the reply body does NOT carry the ANSWER.txt token ($TOKEN) — wrong/missing answer"; fail=1; fi
exit "$fail"
