#!/usr/bin/env bash
# JUDGE: the resume double-act scenario was injected (re-delivered + cold-restart). Without it, exactly-once
# is untested — so a run where the fault never fired is not a valid proof.
# PASS (exit 0): the injector recorded restart.done (it re-delivered the message + cold-killed ih.agent).
set -uo pipefail
ROOT="${CATALOG:-$PWD}"; STAMP="$ROOT/.stev/restart.done"; RLOG="$ROOT/.stev/restart.log"
if [ -f "$STAMP" ]; then
  echo "PASS: the resume double-act scenario was injected (re-delivered + cold-restart)"
  [ -f "$RLOG" ] && sed 's/^/  /' "$RLOG"
  exit 0
else
  echo "FAIL: no restart injected this run — the exactly-once claim is untested; re-run"
  [ -f "$RLOG" ] && sed 's/^/  /' "$RLOG"
  exit 1
fi
