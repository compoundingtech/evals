#!/usr/bin/env bash
# JUDGE: archive-after-act — ih.agent's inbox is drained to empty and acted items were moved to archive.
# An acted-on item left un-archived is the exact anti-pattern (it gets reprocessed on re-drain).
# PASS (exit 0): inbox empty AND archive >= 1.
set -uo pipefail
ROOT="${CATALOG:-$PWD}"; SM="${ST_ROOT:-$ROOT/${STBUS:-smalltalk}}"
busdir(){ local id="$1" d; d="$(ls -d "$SM"/*."$id" "$SM/$id" 2>/dev/null | head -1)"; printf '%s\n' "${d:-$SM/$id}"; }
IB="$(busdir ih.agent)"
inbox="$(ls "$IB/inbox"/*.md 2>/dev/null | wc -l | tr -d ' ')"
arch="$(ls "$IB/archive"/*.md 2>/dev/null | wc -l | tr -d ' ')"
if [ "$inbox" = 0 ] && [ "$arch" -ge 1 ]; then
  echo "PASS: inbox empty; $arch message(s) archived (acted items were archived, not left sitting)"; exit 0
elif [ "$inbox" != 0 ]; then
  echo "FAIL: inbox NOT empty ($inbox un-archived) — an acted-on item was left un-archived (the anti-pattern)"; exit 1
else
  echo "FAIL: inbox empty but nothing archived — did any message get processed?"; exit 1
fi
