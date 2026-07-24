#!/usr/bin/env bash
# HOOK-EXCLUSIVE (attribution guard): the token must appear in NO agent SEED INPUT — not the persona the agent
# reads, not the delivered kick, not the repo at seed. It lives ONLY in each leg's context/now.md (the hook
# channel). The agent's OUTPUTS legitimately carry it — HOOK_OK.txt (the sentinel it writes), its bus REPORT to the
# requester ("done, wrote REHYDRATE-…"), and its transcript — so those are excluded. This is what makes a produced
# token attributable to the hook, and guards against a future change that would leak it into a non-hook input.
set -uo pipefail
SB="${CATALOG:?CATALOG not set}"
tok="$(tr -d '[:space:]' < "$SB/want.txt" 2>/dev/null)"
[ -n "$tok" ] || { echo "FAIL: no ground-truth token ($SB/want.txt) — did the setup step run?"; exit 1; }
hits=0
report(){ echo "  token leaked into an agent INPUT: $1"; hits=$((hits+1)); }

# 1) the seed persona + kick fixture the agents read
for f in "$SB/persona.md" "$SB/task.md"; do grep -qF "$tok" "$f" 2>/dev/null && report "$f"; done
# 2) each leg's rendered overlay the agent loads (persona/bus/rules) + its repo AT SEED (git HEAD, NOT the working
#    tree — HOOK_OK.txt is a runtime output)
for leg in repo-on repo-off; do
  while IFS= read -r m; do report "$m"; done < <(grep -rlF "$tok" "$SB/$leg/.convoy" "$SB/$leg/.claude" 2>/dev/null)
  git -C "$SB/$leg" grep -qF "$tok" HEAD 2>/dev/null && report "$leg@HEAD (seed commit)"
done
# 3) the kick delivered to EACH agent's OWN inbox (their input) — NOT the requester's inbox (the agent's report OUTPUT)
for id in hi.on hi.off; do
  while IFS= read -r m; do report "$m"; done < <(grep -rlF "$tok" "$SB/smalltalk/$id/inbox" 2>/dev/null)
done

[ "$hits" -eq 0 ] || { echo "FAIL: the token appears in $hits agent SEED INPUT(s) beyond context/now.md — attribution is not hook-exclusive"; exit 1; }
echo "PASS: the token appears in NO agent seed input (persona/kick/repo-seed/inbox) beyond context/now.md — a produced token is attributable ONLY to the SessionStart hook firing"
