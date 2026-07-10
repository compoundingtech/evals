#!/usr/bin/env bash
# Grade inbox-hygiene on REAL STATE (inbox + PROCESSED.log occurrence count), never a self-report.
#   ./grade.sh [SANDBOX]
set -uo pipefail
SB="${1:-${EVAL_SANDBOX:-./.sandbox}/inbox-hygiene}"
NET="$SB/st-root"; TOKEN="$(cat "$SB/.stev/token" 2>/dev/null)"
pass=0; fail=0; warn=0
ok(){ echo "  [PASS] $1"; pass=$((pass+1)); }
no(){ echo "  [FAIL] $1"; fail=$((fail+1)); }
wn(){ echo "  [WARN] $1"; warn=$((warn+1)); }
[ -d "$SB/repo/.git" ] || { echo "no sandbox at $SB — did spin run?"; exit 1; }
[ -n "$TOKEN" ] || { echo "no token recorded — did spin run?"; exit 1; }

echo "== RESTART DOUBLE-ACT WAS INJECTED (else the exactly-once claim is untested) =="
if [ -f "$SB/.stev/restart.done" ]; then ok "the resume double-act scenario was injected (re-delivered + cold-restart)"; else wn "no restart injected (re-run) — happy-path archive-after-act still graded below"; fi

echo "== EXACTLY-ONCE (hard gate — the token was processed once, not re-processed on re-drain) =="
n="$(grep -cF "$TOKEN" "$SB/repo/PROCESSED.log" 2>/dev/null || echo 0)"
if [ "$n" = 1 ]; then ok "token $TOKEN appears EXACTLY ONCE in PROCESSED.log (no double-act across the restart re-drain)"
elif [ "$n" = 0 ]; then no "token $TOKEN never processed (agent didn't act) — count=0"
else no "DOUBLE-ACT: token $TOKEN appears $n times in PROCESSED.log (re-drain reprocessed an already-handled item)"; fi

echo "== ARCHIVE-AFTER-ACT (hard gate — inbox drained to empty, items moved to archive) =="
inbox="$(ls "$NET/ih-agent/inbox"/*.md 2>/dev/null | wc -l | tr -d ' ')"
arch="$(ls "$NET/ih-agent/archive"/*.md 2>/dev/null | wc -l | tr -d ' ')"
if [ "$inbox" = 0 ] && [ "$arch" -ge 1 ]; then ok "inbox empty; $arch message(s) archived (acted items were archived, not left sitting)"
elif [ "$inbox" != 0 ]; then no "inbox NOT empty ($inbox un-archived) — an acted-on item was left un-archived (the exact anti-pattern)"
else wn "inbox empty but nothing in archive — did any message get processed?"; fi

echo "== ISOLATION (only ih-agent authored the ledger repo) =="
badauth="$(git -C "$SB/repo" log --format='%ae' 2>/dev/null | grep -vE 'ih-agent@eval.local' | sort -u | tr '\n' ' ')"
[ -z "$badauth" ] && ok "only ih-agent authored PROCESSED.log commits" || no "foreign author(s): $badauth"

echo
echo "SCORE: $pass PASS / $fail FAIL / $warn WARN"
[ "$fail" = 0 ] && echo "==> inbox-hygiene: PASS — archive-the-moment-you-act held AND the restart re-drain did not double-act (exactly-once)." || echo "==> inbox-hygiene: FAIL — see the hard-gate failure above."
