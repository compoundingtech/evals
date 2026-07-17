#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# Ground-truth grader for CONVOY-INIT-STRUCTURE. Asserts the REAL `convoy init <net>` produced the redesign
# target layout: <net>/{smalltalk,pty,worktrees} + a recorded network config. Never a self-report — grades the
# on-disk shape probe.sh captured. Mutation-valid: a missing/wrong subdir FAILS (that is the whole point of a
# structure gate), and a self-test proves the presence check is non-vacuous.
#
# Expect RED until convoy's named-net + smalltalk/pty/worktrees pieces land; GREEN after — the regression guard.
#   ./grade.sh [SANDBOX]
# ─────────────────────────────────────────────────────────────────────────────
set -uo pipefail
SB="${1:-${EVAL_SANDBOX:-/tmp}/cis}"
P="$SB/.probe"
pass=0; fail=0; warn=0; skip=0
ok(){ echo "  [PASS] $1"; pass=$((pass+1)); }
no(){ echo "  [FAIL] $1"; fail=$((fail+1)); }
wn(){ echo "  [WARN] $1"; warn=$((warn+1)); }
sk(){ echo "  [SKIP] $1"; skip=$((skip+1)); }
[ -d "$P" ] || { echo "no probe artifacts at $P — run probe.sh first"; exit 1; }
if grep -q 'CONVOY-MISSING' "$P/init.out" 2>/dev/null; then sk "convoy not available"; echo "SCORE: skipped"; exit 0; fi
[ -f "$P/convoy-version.txt" ] && { echo "convoy under test:"; sed 's/^/  /' "$P/convoy-version.txt"; }

echo "== STRUCTURE (hard gate) — convoy init <net> => <net>/{smalltalk,pty,worktrees} =="
for d in smalltalk pty worktrees; do
  grep -q "^has_$d=yes" "$P/shape.txt" && ok "<net>/$d/ exists" \
                                       || no "<net>/$d/ MISSING — convoy init did not create it (redesign piece not landed / regressed)"
done

echo "== NAMED NETWORKS (hard gate, redesign #2) — a bare name resolves under <state>/convoy/<name>/; a path is used as-is =="
grep -q '^named_net=yes' "$P/shape.txt" && ok "a bare NAME resolves under <state-home>/convoy/<name>/ (named networks live)" \
                                        || no "a bare name did NOT create <state>/convoy/<name>/ — named networks (#2) not landed"
grep -q '^path_as_is=yes' "$P/shape.txt" && ok "an explicit PATH is used as-is" \
                                         || no "an explicit path was not used as-is"

echo "== CONFIG RECORDED (hard gate) — init recorded the network config =="
cfg="$(sed -n 's/^config_recorded=//p' "$P/shape.txt")"
[ -n "$cfg" ] && [ "$cfg" != "no" ] && ok "network config recorded ($cfg)" \
                                    || no "no recorded network config — add/up/doctor cannot stay consistent (exact filename TBD w/ convoy-claude)"

echo "== MUTATION-VALID (hard gate) — the presence check is non-vacuous =="
grep -q '^selftest_bogus_absent=yes' "$P/shape.txt" && ok "a bogus subdir reads ABSENT — the structure check genuinely tests presence (not always-pass)" \
                                                    || no "self-test failed — the presence check may be vacuous"

echo
echo "== observed tree (context) =="; sed 's/^/     /' "$P/tree.txt" 2>/dev/null | head -20

echo
echo "SCORE: $pass PASS / $fail FAIL / $warn WARN / $skip SKIP"
if [ "$fail" -eq 0 ]; then
  echo "==> convoy-init-structure: PASS — convoy init produces the redesign layout (<net>/{smalltalk,pty,worktrees} + config)."
else
  echo "==> convoy-init-structure: FAIL — the init layout does not match the redesign target. Expected RED until the"
  echo "    named-net + smalltalk/pty/worktrees pieces land; this cell is the regression guard for that structure."
fi
[ "$fail" -eq 0 ]
