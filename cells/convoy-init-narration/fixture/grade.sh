#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# Ground-truth grader for CONVOY-INIT-NARRATION. Asserts the redesign's narrated `convoy init` (redesign #5, convoy
# #60): the default run narrates the key steps in plain language, `--quiet` is silent, `--json` emits a one-line
# machine summary. Never a self-report — grades the captured stdout. Mutation-valid: --quiet=0-lines vs default=
# narrated is the built-in contrast (a non-narrating init fails default; an un-silenced --quiet fails quiet), plus
# a self-test that a not-present phrase reads absent.
#   ./grade.sh [SANDBOX]
# ─────────────────────────────────────────────────────────────────────────────
set -uo pipefail
SB="${1:-${EVAL_SANDBOX:-/tmp}/cin}"
P="$SB/.probe"
pass=0; fail=0; warn=0; skip=0
ok(){ echo "  [PASS] $1"; pass=$((pass+1)); }
no(){ echo "  [FAIL] $1"; fail=$((fail+1)); }
sk(){ echo "  [SKIP] $1"; skip=$((skip+1)); }
g(){ grep -q "^$1" "$P/shape.txt"; }
[ -d "$P" ] || { echo "no probe artifacts at $P — run probe.sh first"; exit 1; }
if grep -q 'CONVOY-MISSING' "$P/shape.txt" 2>/dev/null; then sk "convoy not available"; echo "SCORE: skipped"; exit 0; fi
[ -f "$P/convoy-version.txt" ] && { echo "convoy under test:"; sed 's/^/  /' "$P/convoy-version.txt"; }

echo
echo "== DEFAULT NARRATION (hard gate) — convoy init tells the user what's happening, step by step =="
dl="$(sed -n 's/^def_lines=//p' "$P/shape.txt")"
[ "${dl:-0}" -ge 5 ] && ok "default init emits substantial step narration ($dl stdout lines)" \
                     || no "default init emitted only ${dl:-0} stdout lines — not narrated (redesign #5 not landed / regressed)"
g "narr_structure=yes"   && ok "narrates creating the network structure" || no "no 'network structure' narration"
g "narr_config=yes"      && ok "narrates recording the network config (convoy.toml)" || no "no 'network config' narration"
g "narr_ready=yes"       && ok "narrates completion (network is ready)" || no "no completion narration"
g "narr_doctor_next=yes" && ok "points the user at the next step (run convoy doctor)" || no "no 'run convoy doctor' next-step pointer"

echo
echo "== --quiet (hard gate) — a scriptable silent mode: ZERO stdout lines =="
ql="$(sed -n 's/^quiet_lines=//p' "$P/shape.txt")"
[ "${ql:-1}" = 0 ] && ok "convoy init --quiet emits 0 stdout lines (silent for scripts/evals)" \
                   || no "convoy init --quiet emitted $ql stdout lines — not silent"

echo
echo "== --json (hard gate) — a one-line machine summary with the network paths =="
jl="$(sed -n 's/^json_lines=//p' "$P/shape.txt")"
[ "${jl:-0}" = 1 ] && ok "convoy init --json emits exactly ONE line" || no "convoy init --json emitted ${jl:-0} lines (expected 1)"
g "json_keys_ok=yes" && ok "the --json summary has all of {network,dir,stRoot,ptyRoot,worktrees}" \
                     || { no "the --json summary is missing keys"; sed -n 's/^json_keys_ok=//p' "$P/shape.txt" | sed 's/^/       /'; }

echo
echo "== MUTATION-VALID (hard gate) — the narration grep is non-vacuous =="
g "selftest_absent=yes" && ok "a not-present phrase reads ABSENT — the narration check genuinely greps the output" \
                        || no "self-test failed — the narration grep may be vacuous"

echo
echo "SCORE: $pass PASS / $fail FAIL / $skip SKIP"
if [ "$fail" -eq 0 ]; then
  echo "==> convoy-init-narration: PASS — convoy init is narrated (step-by-step default), silent under --quiet, and"
  echo "    emits a one-line --json summary. The Johannes-usability half: init tells a first-timer what it's doing."
else
  echo "==> convoy-init-narration: FAIL — the narrated-init UX does not match the target (redesign #5 / convoy #60)."
fi
[ "$fail" -eq 0 ]
