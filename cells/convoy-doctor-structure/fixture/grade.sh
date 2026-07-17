#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# Ground-truth grader for CONVOY-DOCTOR-STRUCTURE. Asserts the redesign's narrated `convoy doctor` (redesign #6,
# convoy #61) proves the network layout: a narrated Structure section that PASSES on a well-formed net and FAILS on
# a malformed one (mutation-valid). Never a self-report — grades doctor's real output. The can-work (--full) half
# is a HELD live headline (fixture/spin.sh, gated) — the structure half is the box-free proof.
#   ./grade.sh [SANDBOX]
# ─────────────────────────────────────────────────────────────────────────────
set -uo pipefail
SB="${1:-${EVAL_SANDBOX:-/tmp}/cds}"
P="$SB/.probe"
pass=0; fail=0; skip=0
ok(){ echo "  [PASS] $1"; pass=$((pass+1)); }
no(){ echo "  [FAIL] $1"; fail=$((fail+1)); }
sk(){ echo "  [SKIP] $1"; skip=$((skip+1)); }
g(){ grep -q "^$1" "$P/shape.txt"; }
[ -d "$P" ] || { echo "no probe artifacts at $P — run probe.sh first"; exit 1; }
if grep -q 'CONVOY-MISSING' "$P/shape.txt" 2>/dev/null; then sk "convoy not available"; echo "SCORE: skipped"; exit 0; fi
[ -f "$P/convoy-version.txt" ] && { echo "convoy under test:"; sed 's/^/  /' "$P/convoy-version.txt"; }

echo
echo "== STRUCTURE SECTION (hard gate) — doctor narrates a Structure section checking the redesign layout =="
g "has_structure_section=yes" && ok "convoy doctor emits the narrated 'Structure' section" \
                              || no "no narrated Structure section — narrated-doctor (#6) not landed / regressed"
for k in 'named network' 'smalltalk/' 'pty/' 'worktrees/' 'host-prefixed bus folders' 'pristine workspaces' 'cold-boot'; do
  g "check_present:$k=yes" && ok "  narrates the '$k' check" || no "  MISSING the '$k' structure check"
done

echo
echo "== WELL-FORMED PASSES (hard gate) — doctor's structure checks all pass on a correct net =="
wf="$(sed -n 's/^well_structure_fail_marks=//p' "$P/shape.txt")"; we="$(sed -n 's/^well_exit=//p' "$P/shape.txt")"
{ [ "${wf:-1}" = 0 ] && [ "${we:-1}" = 0 ]; } && ok "on a well-formed net: 0 structure ✗ marks + doctor exit 0 (structure PROVEN correct)" \
                                             || no "on a well-formed net: $wf structure ✗ / exit $we — doctor did not pass the structure of a correct net"

echo
echo "== MALFORMED FAILS (hard gate, MUTATION-VALID) — doctor flags a broken layout =="
bwt="$(sed -n 's/^bad_worktrees_flagged=//p' "$P/shape.txt")"; be="$(sed -n 's/^bad_exit=//p' "$P/shape.txt")"
{ [ "${bwt:-0}" -ge 1 ] && [ "${be:-0}" != 0 ]; } && ok "on a MALFORMED net (worktrees/ removed): doctor flags worktrees/ ✗ + non-zero exit — the structure gate is REAL (not always-pass)" \
                                                   || no "doctor did NOT flag the removed worktrees/ (flags=$bwt exit=$be) — the structure check is vacuous"

echo
echo "== CAN-WORK (headline, --full, HELD) — the CoS→sup→worker graded proof on the new-layout sandbox =="
if [ -f "$SB/.stev/canwork.log" ]; then
  grep -q '^canwork=pass' "$SB/.stev/canwork.log" && ok "convoy doctor --full proved can-work (CoS→sup→worker graded PASS) on the isolated new-layout net" \
                                                   || no "convoy doctor --full did not report can-work PASS"
else
  sk "can-work (--full) not exercised — it spawns a real CoS→sup→worker (heavy/box); run fixture/spin.sh. The box-free structure half above carries the layout proof."
fi

echo
echo "== ISOLATION (hard gate) — scoped to the sandbox; the real fleet is untouched =="
leak="$(pty ls 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g' | grep -cE 'doctor|cds-' || true)"
[ "${leak:-0}" = 0 ] && ok "no doctor/cds session in the operator's global pty root (--network scoped it to the sandbox)" \
                     || no "LEAK: a session escaped to the global pty root (pty=$leak)"

echo
echo "SCORE: $pass PASS / $fail FAIL / $skip SKIP"
if [ "$fail" -eq 0 ]; then
  echo "==> convoy-doctor-structure: PASS — convoy doctor narrates + PROVES the redesign layout (structure-correct on a"
  echo "    good net, flags a bad one). With this the whole structure redesign (#1–#6) is guarded end-to-end."
else
  echo "==> convoy-doctor-structure: FAIL — doctor's structure proof does not match the target (redesign #6 / convoy #61)."
fi
[ "$fail" -eq 0 ]
