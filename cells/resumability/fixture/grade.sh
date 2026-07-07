#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# Grader for resumability. Proves `st launch` RESUMES the pinned session by DEFAULT (so agents keep their context
# across the reboot migration — which preserves each agent's .claude-session-id) and that --fresh is the clean
# opt-out that LEAVES THE PIN INTACT. Deterministic (grades the --dry-run probe). This is the mechanism the reboot
# relies on; if it breaks, agents silently lose context on relaunch.
#   ./grade.sh [SANDBOX]
# ─────────────────────────────────────────────────────────────────────────────
set -uo pipefail
SB="${1:-${EVAL_SANDBOX:-./.sandbox}/resumability}"
P="$SB/.probe"
pass=0; fail=0
ok(){ echo "  [PASS] $1"; pass=$((pass+1)); }
no(){ echo "  [FAIL] $1"; fail=$((fail+1)); }
[ -f "$P/default.txt" ] || { echo "no probe at $P — run probe.sh first"; exit 1; }
SID="$(tr -d '\r\n' < "$P/sid-before.txt" 2>/dev/null)"

echo "== RESUME (default launch resumes the pinned session — context preserved) =="
if grep -qF -- "--resume $SID" "$P/default.txt"; then
  ok "default launch RESUMES the pinned session (--resume $SID) — the agent keeps its context (exactly what the reboot migration relies on)"
else
  no "default launch did NOT --resume the pinned session-id ($SID) — agents would silently lose context on relaunch"
fi

echo "== FRESH (--fresh omits --resume — the deliberate opt-out) =="
if grep -qE -- '(^|[[:space:]])--resume([[:space:]]|$)' "$P/fresh.txt"; then
  no "--fresh STILL passed --resume — the fresh opt-out is broken (no way to start clean)"
else
  ok "--fresh OMITS --resume (a genuinely fresh context; must rehydrate from git+bus) — the opt-out works"
fi

echo "== PIN PRESERVED (--fresh is one-off — the pin survives for the next resume) =="
if [ "$(tr -d '\r\n' < "$P/sid-after.txt" 2>/dev/null)" = "$SID" ]; then
  ok "the pinned .claude-session-id is UNCHANGED after --fresh ($SID) — the next non-fresh launch resumes as usual"
else
  no "the pinned .claude-session-id CHANGED after --fresh — --fresh wrongly clobbered the pin (would break the next resume)"
fi

echo
echo "SCORE: $pass PASS / $fail FAIL"
echo "BEHAVIORAL (live headline, rides the box): a DEFAULT-resumed agent still knows CONTEXT.md's prior token in-context; a --fresh agent rehydrates from durable state (git+bus). 0 rescues either way."
[ "$fail" -eq 0 ] && echo "==> resumability: PASS — st launch resumes the pinned session by default (migration-safe), --fresh cleanly opts out + leaves the pin intact." \
                   || echo "==> resumability: FAIL — see [FAIL] rows (the reboot migration relies on this)."
[ "$fail" -eq 0 ]
