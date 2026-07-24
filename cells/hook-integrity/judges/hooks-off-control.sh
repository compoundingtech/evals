#!/usr/bin/env bash
# HOOKS-OFF CONTROL (hard gate — the negative leg, DRIFT-PROOF): the OFF leg boots `--settings disableAllHooks`
# with the SAME hooks configured (the real session-start.sh AND the witness) and the SAME now.md seeded, differing
# ONLY in whether claude fires them. With hooks suppressed, the witness NEVER runs → no OFF-leg witness file. The
# witness is a hook side-effect the model CANNOT forge: even though the OFF-leg agent can reach now.md via
# `st context read` (a non-hook path) and write the token elsewhere, it cannot create the hook's witness. So this
# control asserts on the witness, not on any model output — the fragility that a check-both-ways / model-read could
# defeat is gone. ON present / OFF absent.
set -uo pipefail
SB="${CATALOG:?CATALOG not set}"
want="$(tr -d '[:space:]' < "$SB/want.txt" 2>/dev/null)"
w="$SB/hook-witness/hi.off.injected"
if [ ! -f "$w" ]; then
  echo "PASS: OFF-leg witness absent — with --settings disableAllHooks the SessionStart hook did NOT fire (negative control holds)"; exit 0
fi
grep -qF "$want" "$w" && { echo "FAIL: OFF-leg witness carries the token — the SessionStart hook FIRED on the control leg (disableAllHooks did not suppress it)"; exit 1; }
echo "PASS: OFF-leg witness present but tokenless — the hook did not emit the seeded payload on the control leg"
