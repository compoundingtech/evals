#!/usr/bin/env bash
# HOOKS-OFF CONTROL (hard gate — the negative leg): the OFF leg booted `--no-hooks` with the SAME rendered hook
# configured and the SAME now.md seeded, differing ONLY in whether claude fires the hook. It must NOT have obtained
# the token. A check that passed BOTH ways would be testing nothing — this control is what makes the ON pass mean
# "the hook fired", not "the token was reachable anyway".
set -uo pipefail
SB="${CATALOG:?CATALOG not set}"
want="$(tr -d '[:space:]' < "$SB/want.txt" 2>/dev/null)"
f="$SB/repo-off/HOOK_OK.txt"
if [ ! -f "$f" ]; then
  echo "PASS: repo-off/HOOK_OK.txt absent — with --no-hooks the SessionStart hook did NOT fire (negative control holds)"; exit 0
fi
got="$(tr -d '[:space:]' < "$f")"
[ "$got" = "$want" ] && { echo "FAIL: repo-off/HOOK_OK.txt carries the token WITHOUT the hook firing — the token was not hook-exclusive / --no-hooks didn't suppress it"; exit 1; }
echo "PASS: repo-off/HOOK_OK.txt present but tokenless ('$got') — the control did not obtain the hook-exclusive token"
