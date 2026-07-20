#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# Ground-truth grader for CONVOY-DOCTOR-FOREIGN-BOX. Asserts the two Johannes doctor FALSE-NEGATIVES stay
# fixed (convoy #77 auth-probe classifier + #78 st-hooks discovery): on a foreign box (st OFF PATH + an
# INCONCLUSIVE claude probe) `convoy doctor` reports HONESTLY — no false "hooks NOT found", no false "Claude
# is NOT signed in". Grades doctor's REAL stdout, never a self-report. Mutation-valid via the CLEAR-SIGNOUT
# contrast (a real not-logged-in signal DOES yield "NOT signed in" — so the honest pass is non-vacuous).
#   ./grade.sh [SANDBOX]
# ─────────────────────────────────────────────────────────────────────────────
set -uo pipefail
SB="${1:-${EVAL_SANDBOX:-/tmp}/cdfb}"
P="$SB/.probe"
pass=0; fail=0; skip=0
ok(){ echo "  [PASS] $1"; pass=$((pass+1)); }
no(){ echo "  [FAIL] $1"; fail=$((fail+1)); }
sk(){ echo "  [SKIP] $1"; skip=$((skip+1)); }
g(){ grep -q "^$1\$" "$P/shape.txt"; }
[ -d "$P" ] || { echo "no probe artifacts at $P — run probe.sh first"; exit 1; }
if grep -q 'PROBE-SKIP' "$P/shape.txt" 2>/dev/null; then sk "convoy or st not available — foreign box not constructible"; echo "SCORE: skipped"; exit 0; fi
[ -f "$P/convoy-version.txt" ] && { echo "convoy under test:"; sed 's/^/  /' "$P/convoy-version.txt"; }

echo
echo "== SCENARIO REAL (hard gate) — st is genuinely OFF PATH in the run (else the guard is vacuous) =="
g "fb_st_offpath=yes" && ok "the foreign box is real: doctor's Tooling leg flags 'st NOT on PATH' (st was removed from the run's PATH)" \
                      || no "st was NOT off PATH in the run — the foreign-box scenario didn't hold, so the honesty gates below prove nothing"

echo
echo "== #78 HOOKS HONESTY (hard gate) — st OFF PATH must NOT be reported as absent hooks =="
g "fb_hooks_notfound=no" && ok "no false 'hooks NOT found' — st off PATH is not mistaken for absent hooks (discovered via ST_BIN, not \`which st\`)" \
                         || no "FALSE-NEGATIVE (#78 regressed): doctor said 'hooks NOT found' with st off PATH — discovery keyed off \`which st\` again instead of ST_BIN"
g "fb_hooks_found=yes"    && ok "doctor honestly reports 'smalltalk hooks found' — off-PATH discovery (ST_BIN) works" \
                         || no "doctor did not confirm the hooks it CAN locate via ST_BIN — off-PATH discovery regressed"

echo
echo "== #77 AUTH HONESTY (hard gate) — an inconclusive probe is 'could not verify', not a false 'signed out' =="
g "fb_auth_inconclusive=yes" && ok "an INCONCLUSIVE probe (a non-auth error) is reported honestly as 'could not verify Claude auth — the probe errored'" \
                             || no "the inconclusive probe was not reported as 'could not verify' — the honest inconclusive wording regressed"
g "fb_auth_signedout=no"     && ok "the inconclusive probe is NOT mislabeled 'Claude is NOT signed in' — no false signed-out" \
                             || no "FALSE-NEGATIVE (#77 regressed): a non-auth probe error was mislabeled 'Claude is NOT signed in' (AUTH_FAIL too broad / classifyProbe order)"

echo
echo "== MUTATION-VALID CONTRAST (hard gate) — a CLEAR signal DOES yield 'NOT signed in' (non-vacuous) =="
g "ct_auth_signedout=yes" && ok "a CLEAR not-logged-in signal DOES produce 'Claude is NOT signed in' — the auth check can and does report signed-out, so the foreign-box pass is meaningful" \
                          || no "even a CLEAR not-logged-in signal did not produce 'NOT signed in' — the auth check is broken/vacuous, so the honest pass proves nothing"

echo
echo "== ISOLATION (hard gate) — scoped to the sandbox; the real fleet is untouched =="
leak="$(pty ls 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g' | grep -cE 'doctor|cdfb|/net' || true)"
[ "${leak:-0}" = 0 ] && ok "no doctor/cdfb session in the operator's global pty root (--network scoped it to the sandbox)" \
                     || no "LEAK: a session escaped to the global pty root (pty=$leak)"

echo
echo "SCORE: $pass PASS / $fail FAIL / $skip SKIP"
if [ "$fail" -eq 0 ]; then
  echo "==> convoy-doctor-foreign-box: PASS — on a foreign box (st off PATH + an inconclusive claude probe) convoy"
  echo "    doctor reports HONESTLY: no false 'hooks NOT found' (#78), no false 'Claude is NOT signed in' (#77); and a"
  echo "    genuine not-logged-in signal still surfaces as signed-out (mutation-valid). The Johannes false-negatives are guarded."
else
  echo "==> convoy-doctor-foreign-box: FAIL — doctor said an untrue thing on the foreign box (a Johannes false-negative"
  echo "    regressed), or the check is vacuous. (If the local convoy predates #77/#78, sync the box to a tree that"
  echo "    includes both fixes, then this flips GREEN.)"
fi
[ "$fail" -eq 0 ]
