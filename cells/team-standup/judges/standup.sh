#!/usr/bin/env bash
# JUDGE: STANDUP — the CoS stood up taskflow-dev as a live RUNTIME seat (not pre-declared). If it came online
# it has a bus dir (it set status available on boot + has a voice on the bus).
# PASS (exit 0): taskflow-dev has a bus dir on the smalltalk bus.
set -uo pipefail
ROOT="${CATALOG:-$PWD}"; SM="${ST_ROOT:-$ROOT/${STBUS:-smalltalk}}"; DEV_ID="${DEV_ID:-taskflow-dev}"
BD="$(ls -d "$SM"/*."$DEV_ID" "$SM/$DEV_ID" 2>/dev/null | head -1)"
if [ -n "$BD" ] && [ -d "$BD" ]; then
  echo "PASS: taskflow-dev was stood up as a live seat (bus dir $BD present — it came online)"; exit 0
else
  echo "FAIL: no bus dir for taskflow-dev — the runtime standup did not bring a live seat online"; exit 1
fi
