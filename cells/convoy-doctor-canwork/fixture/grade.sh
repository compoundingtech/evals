#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# Ground-truth grader for CONVOY-DOCTOR-CANWORK. Asserts convoy's OWN end-to-end self-test — `convoy doctor --full`
# proves the full autonomous org works on this machine (a real CoS→sup→worker delegated + shipped a graded fix,
# hands-off). Never a self-report — grades doctor's real stderr markers + exit code. Two layers:
#   BOX-FREE FLOOR (probe.sh): doctor --full FAILS-CLOSED on a bad preflight (rc=1 short-circuit) — a PREFLIGHT
#     negative (honestly labeled: proves the preflight gate, NOT the org grader).
#   LIVE HEADLINE (spin.sh, gated): the ORG-PROOF CORE — g1 + cos→sup + sup→wk + graded_fix — is the HARD gate
#     (straddle-INDEPENDENT). rc + the PASS-headline + the restart-straddle are ADVISORY (straddle-coupled,
#     single-run: convoy confirmed checkFullOrg is ONE pass/fail for G1..G5, so rc + PASS-headline both fail on a
#     straddle flake — gating on them would make the eval flaky). Promote them once convoy makes the straddle deterministic.
#   ./grade.sh [SANDBOX]
# ─────────────────────────────────────────────────────────────────────────────
set -uo pipefail
SB="${1:-${EVAL_SANDBOX:-/tmp}/cdc}"
P="$SB/.probe"
LOG="$SB/.stev/canwork.log"
pass=0; fail=0; skip=0
ok(){ echo "  [PASS] $1"; pass=$((pass+1)); }
no(){ echo "  [FAIL] $1"; fail=$((fail+1)); }
sk(){ echo "  [SKIP] $1"; skip=$((skip+1)); }
note(){ echo "  [note] $1"; }
g(){ grep -q "^$1\$" "$P/shape.txt"; }
lf(){ grep -oE "(^|[[:space:]])$1=[a-z0-9]+" "$LOG" 2>/dev/null | head -1 | sed 's/.*=//'; }   # read a key=val token from canwork.log (start-of-line or space-delimited; avoids src=/rc= overlap)
[ -d "$P" ] || { echo "no probe artifacts at $P — run probe.sh first"; exit 1; }
if grep -q 'CONVOY-MISSING' "$P/shape.txt" 2>/dev/null; then sk "convoy not available"; echo "SCORE: skipped"; exit 0; fi
[ -f "$P/convoy-version.txt" ] && { echo "convoy under test:"; sed 's/^/  /' "$P/convoy-version.txt"; }

echo
echo "== PREFLIGHT FAILS-CLOSED (hard gate, box-free) — doctor --full refuses a broken layout BEFORE spawning an org =="
g "pre_rc=1"            && ok "doctor --full --network <malformed> exits rc=1 (fails-closed, does not proceed)" \
                        || no "doctor --full did not exit rc=1 on a malformed net (pre_rc != 1) — it did not fail closed"
g "pre_preflight_fail=yes" && ok "a preflight structure ✗ (worktrees/ MISSING) is shown — the fail is the preflight, as designed" \
                           || no "no preflight structure ✗ on a malformed net — the preflight did not catch the break"
g "pre_headline_pass=no" && ok "the can-work headline is ABSENT on the malformed run (org proof short-circuited, never ran)" \
                         || no "the can-work headline appeared on a malformed net — the org proof ran despite a bad preflight"
note "SCOPE: this is a PREFLIGHT negative (proves doctor fails-closed on bad structure), NOT proof the org grader catches a bad fix."
note "The can-work-GRADER mutation-validity is a DURABLE held-out test in convoy: src/doctor/fixtures/grader/ghost-bug-regression.mjs —"
note "  doctor --full runs it against BOTH the worker repo (must PASS) AND the pristine buggy fixture src/doctor/fixtures/ghost-bug/ (must FAIL)."
note "  Ungameable: it targets the exact call interaction the fixture's green suite never exercises + lives outside the repo (worker can't tune to it)."
note "A true EXTERNAL can-work mutation knob (a force-bad-fix path in shipped doctor) was DECLINED by Nathan (via cos-relay) as a footgun — the durable ghost-bug-regression.mjs cross-ref IS the mutation-validity handle (final)."

echo
echo "== CAN-WORK ORG PROOF (live, --full, gated) — the real CoS→sup→worker graded org, DETERMINISTIC post-#28 =="
if [ -f "$LOG" ] && ! grep -q 'orgcore=skip' "$LOG"; then
  echo "  (doctor --full run:  $(tr '\n' ' ' < "$LOG"))"
  oc="$(lf orgcore)"; g1="$(lf g1)"; cs="$(lf cos_sup)"; sw="$(lf sup_wk)"; gf="$(lf graded_fix)"
  { [ "$oc" = pass ] && [ "$g1" = pass ] && [ "$cs" = pass ] && [ "$sw" = pass ] && [ "$gf" = pass ]; } \
    && ok "org-proof CORE PASS: g1(CoS hands-off boot) + cos→sup + sup→wk + graded_fix — a real CoS→sup→worker delegated + shipped a GRADED fix" \
    || no "org-proof core did not fully pass (orgcore=$oc g1=$g1 cos_sup=$cs sup_wk=$sw graded_fix=$gf) — the autonomous org can-work proof failed"
  # POST-#28 HARD gates — deterministic (the retry-then-advisory straddle no longer gates rc/headline).
  rcv="$(lf rc)"; hl="$(lf headline)"; pr="$(lf prod)"
  [ "$rcv" = 0 ]   && ok "convoy doctor --full exit rc=0 (deterministic post-#28: preflight-green + full-org PASS + prod-untouched)" \
                   || no "convoy doctor --full exit rc=$rcv (a full-org gate or prod-untouched failed)"
  [ "$hl" = pass ] && ok "the stdout PASS-headline is present (the full autonomous org works on this machine ...)" \
                   || no "the PASS-headline is '$hl' (expected pass) — doctor did not declare the org works end-to-end"
  [ "$pr" = yes ]  && ok "prod untouched — the org proof ran in doctor's own sandbox + left prod (sessions/crons/config) alone" \
                   || no "prod-untouched not confirmed (prod='$pr')"
  # ADVISORY (reported, NEVER gated) — the restart-straddle (retry-then-advisory).
  note "ADVISORY (not gated): restart-straddle=$(lf straddle) — retry-then-advisory; promote to a hard gate only if convoy confirms deterministic reconstruction."
  note "marker source: $(lf src) (token = convoy's stable [full-org] GATE line; prose = interim fallback)"
else
  sk "can-work org proof (--full) not exercised — it spawns a real CoS→sup→worker org (heavy/box/real-API); run fixture/spin.sh. The box-free preflight-fails-closed floor above still holds."
fi

echo
echo "== ISOLATION (hard gate) — scoped to the sandbox; the real fleet is untouched =="
leak="$(pty ls 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g' | grep -cE 'doctor|cdc-|/well|/bad' || true)"
[ "${leak:-0}" = 0 ] && ok "no doctor/cdc session in the operator's global pty root (--network scoped it to the sandbox)" \
                     || no "LEAK: a session escaped to the global pty root (pty=$leak)"

echo
echo "SCORE: $pass PASS / $fail FAIL / $skip SKIP"
if [ "$fail" -eq 0 ]; then
  echo "==> convoy-doctor-canwork: PASS — convoy doctor --full fails-closed on a bad preflight, and (when exercised) proves"
  echo "    the org-proof core: a real CoS→sup→worker delegated + shipped a graded fix, hands-off (straddle advisory until deterministic)."
else
  echo "==> convoy-doctor-canwork: FAIL — the can-work self-test does not match the contract (convoy doctor --full)."
fi
[ "$fail" -eq 0 ]
