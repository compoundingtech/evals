#!/usr/bin/env bash
# JUDGE: exactly-once (held-out) — the TOKEN appears EXACTLY ONCE in PROCESSED.log. n=0 = never acted;
# n>1 = a double-act (the re-drain reprocessed an already-handled item). The ungameable countable side-effect.
# PASS (exit 0): count == 1.
set -uo pipefail
ROOT="${CATALOG:-$PWD}"; L="$ROOT/worker"; TOKEN="${IH_TOKEN:-IH-9f3a7c2e}"
[ -f "$L/PROCESSED.log" ] || { echo "FAIL: no PROCESSED.log at $L — did the run happen?"; exit 1; }
n="$(grep -cF "$TOKEN" "$L/PROCESSED.log" 2>/dev/null || echo 0)"
if [ "$n" = 1 ]; then
  echo "PASS: token $TOKEN appears EXACTLY ONCE in PROCESSED.log (no double-act across the restart re-drain)"; exit 0
elif [ "$n" = 0 ]; then
  echo "FAIL: token $TOKEN never processed (agent didn't act) — count=0"; exit 1
else
  echo "FAIL: DOUBLE-ACT — token $TOKEN appears $n times in PROCESSED.log (re-drain reprocessed an already-handled item)"; exit 1
fi
