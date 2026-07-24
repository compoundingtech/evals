#!/usr/bin/env bash
# JUDGE: restart injected + the worker RESUMED. The fault injector recorded restart_epoch to
# .stev/restart.log; item commits must STRADDLE it (>=1 before AND >=1 after) — proof the cold-booted worker
# resumed post-restart rather than front-loading everything before. If no restart was injected this run, the
# cell's core wasn't exercised → FAIL (re-run). At-least-once: duplicate item commits are fine.
# PASS (exit 0): a restart was injected AND >=1 item commit lands at/after restart_epoch.
set -uo pipefail
ROOT="${CATALOG:-$PWD}"
W="$ROOT/worker"; RLOG="$ROOT/.stev/restart.log"
[ -d "$W/.git" ] || { echo "FAIL: no ledger repo at $W"; exit 1; }
if [ ! -f "$RLOG" ] || ! grep -q '^restart_epoch=' "$RLOG"; then
  if [ -f "$RLOG" ] && grep -q '^no_restart' "$RLOG"; then
    echo "FAIL: NO restart injected this run ($(grep '^no_restart' "$RLOG" | tail -1)) — resumption NOT exercised; re-run"
  else
    echo "FAIL: no restart.log with an epoch — the fault injection did not run (resumption unproven)"
  fi
  exit 1
fi
EPOCH=$(grep '^restart_epoch=' "$RLOG" | tail -1 | cut -d= -f2)
before=0; after=0
while read -r at; do
  [ -n "$at" ] || continue
  if [ "$at" -lt "$EPOCH" ]; then before=$((before+1)); else after=$((after+1)); fi
done < <(git -C "$W" log --format='%at %s' 2>/dev/null | grep -E ' feat: item ' | awk '{print $1}')
echo "  restart_epoch=$EPOCH  item-commits before=$before after=$after"
if [ "$after" -ge 1 ] && [ "$before" -ge 1 ]; then
  echo "PASS: item commits straddle the restart (>=1 before AND >=1 after) — the worker RESUMED post-restart"; exit 0
elif [ "$after" -eq 0 ]; then
  echo "FAIL: no item commit AFTER the restart — the cold-booted worker did NOT resume"; exit 1
else
  echo "FAIL: no item commit BEFORE the restart epoch — injector timing/clock suspect (checkpoint should be item-2)"; exit 1
fi
