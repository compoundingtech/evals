#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# Grader for the convoy-network CAPSTONE — the reboot GO/NO-GO. Parses `convoy up`'s --json event log + the bus.
# Gates: HOSTED (convoy up is the host) · NO-MCP · NO-APP · RESPAWN (the host brought the killed worker back — the
# genuinely-new gate) · LOOP-CLOSED (a threaded reply reached the requester) · autonomy 0. If this passes, the
# reboot's hosting model works end-to-end.
#   ./grade.sh [SANDBOX]
# ─────────────────────────────────────────────────────────────────────────────
set -uo pipefail
SB="${1:-${EVAL_SANDBOX:-./.sandbox}/convoy-network}"
NET="$SB/net"; LOG="$SB/.convoy-up.log"
pass=0; fail=0; warn=0
ok(){ echo "  [PASS] $1"; pass=$((pass+1)); }
no(){ echo "  [FAIL] $1"; fail=$((fail+1)); }
wn(){ echo "  [WARN] $1"; warn=$((warn+1)); }
kickfn="$(cat "$SB/.kick-filename" 2>/dev/null)"
token="$(tr -d '\r\n' < "$SB/worker/ANSWER.txt" 2>/dev/null)"

# convoy up block-buffers its --json stdout (a LIVE finding — a live consumer sees no events while it hosts). If
# the host is still running, stop it (SIGINT → graceful teardown) to FLUSH the buffered events into the log first.
if [ -f "$SB/.convoy-up.pid" ] && ps -p "$(cat "$SB/.convoy-up.pid" 2>/dev/null)" >/dev/null 2>&1; then
  kill -INT "$(cat "$SB/.convoy-up.pid")" 2>/dev/null || true
  for _ in 1 2 3 4 5 6; do ps -p "$(cat "$SB/.convoy-up.pid" 2>/dev/null)" >/dev/null 2>&1 || break; sleep 1; done
fi

echo "== HOSTED (hard — convoy up is the foreground host/supervisor) =="
if [ -s "$LOG" ] && grep -q '"type":"up"' "$LOG" 2>/dev/null; then ok "convoy up emitted its host 'up' event — the network is hosted by the CLI host (not detached one-offs)"
else no "no convoy up 'up' event in $LOG — the network was not hosted by convoy up"; fi

echo "== NO MCP (hard — the MCP-less config: convoy add ding-default skips .mcp.json) =="
mcp=""; [ -f "$SB/cos/.mcp.json" ] && mcp="$mcp cos"; [ -f "$SB/worker/.mcp.json" ] && mcp="$mcp worker"
[ -z "$mcp" ] && ok "no .mcp.json in either agent dir — the whole network joined via ding + the st CLI, no MCP" \
              || no "an .mcp.json exists ($mcp) — NOT the MCP-less config"

echo "== NO APP (hard — the CLI host, not Convoy.app) =="
if grep -q 'Convoy.app\|/Applications/Convoy' "$LOG" 2>/dev/null; then no "the host log references Convoy.app — an app dependency crept in"
else ok "hosted by 'convoy up' (CLI); no Convoy.app invocation in the host log — no app dependency"; fi

echo "== RESPAWN (hard — the genuinely-new gate: the host brought the crashed PERMANENT agent back) =="
if grep '"type":"respawn"' "$LOG" 2>/dev/null | grep '"identity":"cap-cos"' | grep -q '"ok":true'; then
  ok "convoy up RESPAWNED cap-cos (the permanent agent) after the injected crash (respawn event, ok:true) — the host OWNS respawn (not the fixture)"
elif [ -f "$SB/.kill.log" ]; then no "cap-cos was crashed but convoy up emitted NO successful respawn event — the host did not bring the permanent agent back"
else wn "no crash was injected (kill-injector didn't run) — the respawn gate was not exercised"; fi

echo "== LOOP CLOSED (held-out — a THREADED reply reached the requester with the answer) =="
reply="$(grep -lRE '^from:[[:space:]]*cap-cos([[:space:]]|$)' "$NET/cap-req/inbox" "$NET/cap-req/archive" 2>/dev/null | head -1)"
if [ -z "$reply" ]; then no "no reply from cap-cos in cap-req's inbox — the loop did not close"
else
  irt="$(grep -E '^in-reply-to:' "$reply" 2>/dev/null | head -1 | sed 's/^in-reply-to:[[:space:]]*//')"
  { [ -n "$kickfn" ] && [ "$irt" = "$kickfn" ]; } && ok "cap-cos replied to cap-req ON THE THREAD (in-reply-to == the kick) — a threaded reply, not a fresh send" \
    || wn "reply present but in-reply-to ($irt) != the kick ($kickfn) — confirm the thread"
  grep -qF "$token" "$reply" 2>/dev/null && ok "the reply carries the ANSWER.txt token ($token) — the worker did the work + the answer flowed back through cos" \
    || no "the reply does not carry the token ($token) — the loop's payload didn't make it"
fi

echo
echo "SCORE (mechanical): $pass PASS / $fail FAIL / $warn WARN"
echo "AUTONOMY (headline): rescues to stand up + host + close the loop + survive the respawn — target 0 (read the run log)."
[ "$fail" -eq 0 ] && echo "==> convoy-network CAPSTONE: PASS — convoy up hosted a ding-only no-MCP network end-to-end, RESPAWNED the crashed permanent cos, and the loop closed. The reboot hosting model works." \
                   || echo "==> convoy-network CAPSTONE: FAIL — see [FAIL] rows (this is the reboot go/no-go)."
[ "$fail" -eq 0 ]
