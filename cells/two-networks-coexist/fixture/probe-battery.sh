#!/usr/bin/env bash
# The held-out CROSS-TALK PROBE BATTERY for two-networks-coexist. Assumes spin.sh has brought both networks live.
# Runs the 5 probes in BOTH directions (A->B and B->A) via real `st`/`pty` calls and asserts ZERO cross-talk.
# ORDER MATTERS: the read-only structural probes (enumerate / fs-scope / pty-visibility) run FIRST on the clean
# two-network state; the MUTATING delivery probes (deliver-collision / cross-address) run LAST — because
# addressing a not-in-this-root agent legitimately creates a DEAD-LETTER dir in the SENDER's own root (the message
# stayed local = the pass condition), which would otherwise trip fs-scope. Emits per-probe PASS/FAIL; exit 0 iff
# every probe passes both ways.
#   ./probe-battery.sh [SANDBOX]
set -uo pipefail
SB="${1:-${EVAL_SANDBOX:-./.sandbox}/two-networks-coexist}"
RA="$SB/st-root-a"; RB="$SB/st-root-b"
PA="$(cat "$SB/.pty-root-a" 2>/dev/null)"; PB="$(cat "$SB/.pty-root-b" 2>/dev/null)"
pass=0; fail=0
ok(){ echo "  [PASS] $1"; pass=$((pass+1)); }
no(){ echo "  [FAIL] $1"; fail=$((fail+1)); }
cnt(){ ls -1 "$1" 2>/dev/null | wc -l | tr -d ' '; }

# ── read-only structural probes (clean state) ─────────────────────────────────
echo "== P-enumerate (each root enumerates ONLY its own agents) =="
A_ag=$(ST_ROOT="$RA" st agents --json 2>/dev/null)
B_ag=$(ST_ROOT="$RB" st agents --json 2>/dev/null)
echo "$A_ag" | grep -q '"beacon-b"' && no "A enumerated B-only 'beacon-b' (cross-enumeration leak)" || ok "A->st agents lists only A's agents (no beacon-b)"
echo "$B_ag" | grep -q '"beacon-a"' && no "B enumerated A-only 'beacon-a' (cross-enumeration leak)" || ok "B->st agents lists only B's agents (no beacon-a)"

echo "== P-fs-scope (each ST_ROOT holds only its own network's agent dirs) =="
[ -d "$RA/beacon-b" ] && no "A's ST_ROOT contains B's beacon-b dir (fs bleed)" || ok "A's ST_ROOT holds only A's dirs (no beacon-b)"
[ -d "$RB/beacon-a" ] && no "B's ST_ROOT contains A's beacon-a dir (fs bleed)" || ok "B's ST_ROOT holds only B's dirs (no beacon-a)"

echo "== P-pty-visibility (neither net can see/peek/inject the other's pty sessions) =="
if [ -n "$PA" ] && [ -n "$PB" ]; then
  pty --root "$PA" ls 2>/dev/null | grep -q '2nb-wk' && no "A's PTY_ROOT LISTS B's session 2nb-wk" || ok "A's PTY_ROOT lists only A's session (B's 2nb-wk invisible)"
  pty --root "$PB" ls 2>/dev/null | grep -q '2na-wk' && no "B's PTY_ROOT LISTS A's session 2na-wk" || ok "B's PTY_ROOT lists only B's session (A's 2na-wk invisible)"
  pty --root "$PA" peek 2nb-wk >/dev/null 2>&1 && no "A could PEEK B's session 2nb-wk (screen leak)" || ok "A cannot peek B's session (refused)"
  pty --root "$PB" send 2na-wk 'x' >/dev/null 2>&1 && no "B could SEND to A's session 2na-wk (keystroke injection)" || ok "B cannot send-inject A's session (refused)"
else
  no "PTY_ROOTs not recorded (\$SB/.pty-root-{a,b}) — did spin.sh run?"
fi

# ── mutating delivery probes (run LAST — they create local dead-letters) ───────
echo "== P-deliver-collision (a message to the SHARED identity 'wk' stays in the sender's root) =="
ST_ROOT="$RA" st message send wk --from sup --subject "A->wk" -m "COLLISION-PROBE-FROM-A" >/dev/null 2>&1
ST_ROOT="$RB" st message send wk --from sup --subject "B->wk" -m "COLLISION-PROBE-FROM-B" >/dev/null 2>&1
grep -rslq 'COLLISION-PROBE-FROM-A' "$RB/wk/inbox" 2>/dev/null && no "A's message to 'wk' LEAKED into B's colliding wk inbox" || ok "A->wk landed only in A (not in B's same-named wk)"
grep -rslq 'COLLISION-PROBE-FROM-B' "$RA/wk/inbox" 2>/dev/null && no "B's message to 'wk' LEAKED into A's colliding wk inbox" || ok "B->wk landed only in B (not in A's same-named wk)"

echo "== P-cross-address (addressing the OTHER net's unique agent NEVER reaches it) =="
bb_before=$(cnt "$RB/beacon-b/inbox"); ba_before=$(cnt "$RA/beacon-a/inbox")
ST_ROOT="$RA" st message send beacon-b --from sup --subject "A->beacon-b" -m "cross from A" >/dev/null 2>&1
ST_ROOT="$RB" st message send beacon-a --from sup --subject "B->beacon-a" -m "cross from B" >/dev/null 2>&1
bb_after=$(cnt "$RB/beacon-b/inbox"); ba_after=$(cnt "$RA/beacon-a/inbox")
[ "$bb_after" = "$bb_before" ] && ok "A addressing B-only 'beacon-b' never reached B (\$RB/beacon-b/inbox unchanged=$bb_after; A dead-letters locally)" || no "A's msg REACHED B's beacon-b ($bb_before->$bb_after) — cross-network delivery LEAK"
[ "$ba_after" = "$ba_before" ] && ok "B addressing A-only 'beacon-a' never reached A (\$RA/beacon-a/inbox unchanged=$ba_after; B dead-letters locally)" || no "B's msg REACHED A's beacon-a ($ba_before->$ba_after) — cross-network delivery LEAK"

echo
echo "PROBE BATTERY: $pass PASS / $fail FAIL"
[ "$fail" -eq 0 ]
