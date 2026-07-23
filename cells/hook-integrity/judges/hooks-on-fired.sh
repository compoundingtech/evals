#!/usr/bin/env bash
# HOOKS-ON FIRED (hard gate): the ON leg wrote REHYDRATE-<token> to HOOK_OK.txt. The token lived ONLY in
# context/now.md, which reaches the agent ONLY if the SessionStart hook FIRES + injects it — so the token's
# presence proves the hook actually ran (execution), not merely that it was configured.
set -uo pipefail
SB="${CATALOG:?CATALOG not set}"
want="$(tr -d '[:space:]' < "$SB/want.txt" 2>/dev/null)"
[ -n "$want" ] || { echo "FAIL: no ground-truth token ($SB/want.txt) — did the setup step run?"; exit 1; }
f="$SB/repo-on/HOOK_OK.txt"
[ -f "$f" ] || { echo "FAIL: repo-on/HOOK_OK.txt absent — the SessionStart hook did not fire (or the agent didn't act on the injected now.md)"; exit 1; }
got="$(tr -d '[:space:]' < "$f")"
[ "$got" = "$want" ] || { echo "FAIL: repo-on/HOOK_OK.txt token mismatch (got '$got', want '$want')"; exit 1; }
echo "PASS: repo-on/HOOK_OK.txt carries $want — the SessionStart hook FIRED + injected context/now.md (the token was hook-exclusive)"
