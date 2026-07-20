#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# Ground-truth grader for CONVOY-DOCTOR-PREINIT. Asserts the Johannes FIRST-COMMAND UX (redesign, convoy
# #63/3fc9dc32d): a brand-new user who runs `convoy doctor` on a FRESH, never-init'd path gets a friendly neutral
# pointer + rc=0 — NOT the old scary ✗ named network / ✗ smalltalk MISSING failure wall (rc=1). Never a
# self-report — grades doctor's real stdout + exit code. Mutation-valid via the POST-init contrast.
#   ./grade.sh [SANDBOX]
# ─────────────────────────────────────────────────────────────────────────────
set -uo pipefail
SB="${1:-${EVAL_SANDBOX:-/tmp}/cdp}"
P="$SB/.probe"
pass=0; fail=0; skip=0
ok(){ echo "  [PASS] $1"; pass=$((pass+1)); }
no(){ echo "  [FAIL] $1"; fail=$((fail+1)); }
sk(){ echo "  [SKIP] $1"; skip=$((skip+1)); }
g(){ grep -q "^$1\$" "$P/shape.txt"; }
[ -d "$P" ] || { echo "no probe artifacts at $P — run probe.sh first"; exit 1; }
if grep -q 'CONVOY-MISSING' "$P/shape.txt" 2>/dev/null; then sk "convoy not available"; echo "SCORE: skipped"; exit 0; fi
[ -f "$P/convoy-version.txt" ] && { echo "convoy under test:"; sed 's/^/  /' "$P/convoy-version.txt"; }

echo
echo "== PRE-INIT NEUTRAL (hard gate) — a fresh net gets a friendly pointer, not a failure wall =="
g "pre_rc=0"       && ok "convoy doctor --quick on a FRESH (uninitialized) net exits rc=0 (not a blocking failure)" \
                   || no "fresh-net doctor exited non-zero (pre_rc != 0) — VERIFY THE CAUSE before blaming #63: an UNRELATED blocking check (e.g. hooks/paths) also yields rc=1. Read pre.out's ✗ lines: if the neutral pointer is present and no scary wall, #63 IS landed and the rc comes from elsewhere (env/setup), not a UX regression"
g "pre_neutral=yes" && ok "stdout carries the neutral 'no network here yet — run convoy init' pointer" \
                    || no "no neutral 'no network here yet' pointer — a first-time user gets no friendly next-step"
g "pre_scary_wall=no" && ok "stdout does NOT contain the old scary '✗ named network' / 'MISSING:' wall on a fresh net" \
                      || no "the old scary '✗ named network' / 'MISSING:' wall is still shown pre-init — the Johannes UX regressed"

echo
echo "== POST-INIT CONTRAST (hard gate, MUTATION-VALID) — the neutral line is PRE-init-specific, not always-printed =="
g "post_neutral=no" && ok "a POST-init net does NOT print the 'no network here yet' pointer (the neutral line is scoped to fresh nets)" \
                    || no "the neutral 'no network here yet' line also prints on a real net — the check is vacuous (always neutral)"
g "post_has_checks=yes" && ok "a POST-init net shows the real Structure check list (doctor still does its full job on a real net)" \
                        || no "a POST-init net did not show the Structure section — doctor is degraded, not just friendlier"

echo
echo "== ISOLATION (hard gate) — scoped to the sandbox; the real fleet is untouched =="
leak="$(pty ls 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g' | grep -cE 'doctor|cdp-|/post|/fresh' || true)"
[ "${leak:-0}" = 0 ] && ok "no doctor/cdp session in the operator's global pty root (--network scoped it to the sandbox)" \
                     || no "LEAK: a session escaped to the global pty root (pty=$leak)"

echo
echo "SCORE: $pass PASS / $fail FAIL / $skip SKIP"
if [ "$fail" -eq 0 ]; then
  echo "==> convoy-doctor-preinit: PASS — a fresh user's very first 'convoy doctor' gets a friendly neutral pointer + rc=0,"
  echo "    and a real net still gets the full checks. The Johannes first-command UX is guarded against a regression to the"
  echo "    old scary failure wall (redesign #63, convoy 3fc9dc32d)."
else
  echo "==> convoy-doctor-preinit: FAIL — the pre-init doctor UX does not match the target (redesign #63 / convoy 3fc9dc32d)."
  echo "    DIAGNOSE before concluding — this cell cannot tell these apart, so check in order:"
  echo "      1. env/setup   — an unrelated blocking ✗ (hooks, PTY_ROOT length) makes rc=1 while #63 IS landed."
  echo "                       Tell: the neutral pointer is PRESENT and no scary wall. Read .probe/pre.out ✗ lines."
  echo "      2. cell staleness — convoy'''s UX/verb surface moved and this assertion is out of date."
  echo "      3. unlanded/regressed — the local convoy predates 3fc9dc32d; sync past #63 and re-run."
fi
[ "$fail" -eq 0 ]
