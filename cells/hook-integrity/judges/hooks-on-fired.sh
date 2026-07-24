#!/usr/bin/env bash
# HOOKS-ON FIRED (hard gate — a hook SIDE-EFFECT, ZERO model-behavior dependence): on the ON leg the SessionStart
# hook FIRED, so the parallel witness (hook-witness.sh) recorded the injected payload (context/now.md, verbatim) to
# $CATALOG/hook-witness/hi.on.injected. Its presence PLUS the run's real token proves the hook actually ran +
# emitted the seeded now.md — not merely that it was configured. The witness is written by the hook itself, so this
# does not depend on the model reading anything (that was the old, drift-defeated HOOK_OK.txt assertion).
set -uo pipefail
SB="${CATALOG:?CATALOG not set}"
want="$(tr -d '[:space:]' < "$SB/want.txt" 2>/dev/null)"
[ -n "$want" ] || { echo "FAIL: no ground-truth token ($SB/want.txt) — did the setup step run?"; exit 1; }
w="$SB/hook-witness/hi.on.injected"
[ -f "$w" ] || { echo "FAIL: ON-leg witness $w absent — the SessionStart hook did NOT fire on the ON leg"; exit 1; }
grep -qF "$want" "$w" || { echo "FAIL: ON-leg witness present but lacks the token $want (hook fired but injected the wrong payload?)"; exit 1; }
echo "PASS: the ON-leg SessionStart hook FIRED — its witness recorded the injected now.md carrying $want (hook execution proven from a side-effect; no model behavior involved)"
