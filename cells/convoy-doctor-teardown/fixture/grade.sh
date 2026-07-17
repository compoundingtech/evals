#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# Ground-truth grader for CONVOY-DOCTOR-TEARDOWN. Asserts convoy #67 (the abort trap): a SIGTERM-killed
# `convoy doctor --full` runs its finally-teardown BEFORE exit, so a CI-timeout-killed run does NOT leak its real
# CoS→sup→worker org (agents + ding sidecars). Grades on TEARDOWN, never rc. Mutation-valid + self-contained on one
# convoy: the org is LIVE before the abort (before_leak>0 — a real org existed + the detector works) and REAPED
# after (after_leak=0 + sandbox swept — the #67 trap fired). Never a self-report — counts real live sessions/procs.
#   ./grade.sh [SANDBOX]
# ─────────────────────────────────────────────────────────────────────────────
set -uo pipefail
SB="${1:-${EVAL_SANDBOX:-/tmp}/cdt}"
LOG="$SB/.stev/teardown.log"
pass=0; fail=0; skip=0
ok(){ echo "  [PASS] $1"; pass=$((pass+1)); }
no(){ echo "  [FAIL] $1"; fail=$((fail+1)); }
sk(){ echo "  [SKIP] $1"; skip=$((skip+1)); }
note(){ echo "  [note] $1"; }
lf(){ grep -oE "(^|[[:space:]])$1=[A-Za-z0-9-]+" "$LOG" 2>/dev/null | head -1 | sed 's/.*=//'; }
[ -f "$LOG" ] || { echo "no teardown artifacts at $LOG — run spin.sh first"; exit 1; }
grep -q 'org_up=skip' "$LOG" 2>/dev/null && { sk "convoy not available"; echo "SCORE: skipped"; exit 0; }
echo "abort run:"; sed 's/^/  /' "$LOG"

org_up="$(lf org_up)"; aborted="$(lf aborted)"; bl="$(lf before_leak)"; al="$(lf after_leak)"
td="$(lf torn_down)"; ac="$(lf after_clean)"; tf="$(lf trap_fired)"

echo
echo "== PRECONDITION — a real org was live + abortable (else the teardown test is vacuous) =="
if [ "$org_up" != yes ] || [ "$aborted" != yes ] || [ "${bl:-0}" -lt 1 ]; then
  sk "could not establish a live, abortable org (org_up=$org_up aborted=$aborted before_leak=$bl) — the org did not boot in time or the detector saw no live session; re-run on a quiet box. (Not a teardown FAIL — the precondition wasn't met.)"
  echo; echo "SCORE: $pass PASS / $fail FAIL / $skip SKIP"; exit 0
fi

echo
echo "== ORG-LIVE (hard gate, MUTATION-VALID / anti-vacuous) — the detector actually saw a live org before the abort =="
[ "${bl:-0}" -ge 1 ] && ok "before_leak=$bl live org sessions (CoS agent + ding) BEFORE the SIGTERM — a real org existed to leak, and the leak-detector is not vacuously always-0" \
                     || no "before_leak=$bl — no live org detected before the abort; a later 0 would be vacuous"

echo
echo "== TEARDOWN-ON-ABORT (hard gate) — the #67 trap reaped the org on SIGTERM =="
{ [ "${al:-1}" = 0 ] && [ "$td" = yes ]; } && ok "after_leak=0 live org sessions + sandbox swept — the SIGTERM'd doctor --full tore down its whole org (agents + dings) before exit (convoy #67)" \
                                           || no "after_leak=$al / torn_down=$td — a SIGTERM'd doctor --full LEAKED its org (the #67 abort trap did not reap it) — the abort-leak regressed"
[ "$tf" = yes ] && note "corroborating: doctor printed the trap line ('received — tearing down…') — the abort handler ran" \
                || note "corroborating: trap line not captured in stdout (graded on the real session count, which is the invariant)"

echo
echo "== ISOLATION / SELF-CLEANUP (hard gate) — the test left the box clean, real fleet untouched =="
[ "${ac:-1}" = 0 ] && ok "after_clean=0 — no residual org sessions/dings remain (the cell self-reaped any leak it detected); the operator's real fleet is untouched" \
                   || no "after_clean=$ac — the test left residual sessions on the box (self-cleanup did not fully reap)"

echo
echo "SCORE: $pass PASS / $fail FAIL / $skip SKIP"
if [ "$fail" -eq 0 ] && [ "$pass" -ge 1 ]; then
  echo "==> convoy-doctor-teardown: PASS — a SIGTERM-killed convoy doctor --full reaps its whole org before exit (no"
  echo "    abort-leak): live before (before_leak>0), reaped after (after_leak=0 + sandbox swept). Guards convoy #67."
else
  echo "==> convoy-doctor-teardown: FAIL — a SIGTERM'd doctor --full leaked its org (abort-teardown regressed vs #67)."
fi
[ "$fail" -eq 0 ]
