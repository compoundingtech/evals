#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# TEAM-STANDUP · P4 — stand up a specialist (HERMETIC / dry-run).
#
# Proves the MECHANICS of the CoS standing up a specialist for a repo, offline:
#   1. `<cli> launch claude --identity taskflow-dev` in the taskflow repo dry-runs to a bootable
#      harness with the CHILD's identity written in (ST_AGENT = taskflow-dev — the HB-3 check) and
#      the boot-ritual hook wired.
#   2. The CoS RECORDS the stood-up specialist in team.md (the roster bookkeeping the standup step
#      requires) — lazily, on first work for the repo.
#
# P4 is necessary-but-not-sufficient: it proves the CoS *can* spin a correctly-wired specialist and
# track it. The real proof that the team WORKS is P5 (spin.sh) — a live delegated task end-to-end.
#
#   ./gate-p4.sh [SANDBOX]     # runs setup-sandbox.sh if the sandbox is absent
# Exit 0 = P4 PASS. Friction is a finding, not a failure.
# ─────────────────────────────────────────────────────────────────────────────
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SB="${1:-${EVAL_SANDBOX:-./.sandbox}/team-standup}"
STR="$SB/st-root"
SPEC="taskflow-dev"

declare -a FRICTION=()
note() { FRICTION+=("$1"); printf '  ⚠ FRICTION: %s\n' "$1"; }
gate() { printf '\n=== %s ===\n' "$1"; }
pass() { printf '  ✓ PASS: %s\n' "$1"; }
fail() { printf '  ✗ FAIL: %s\n' "$1"; GATE_FAIL=1; }
GATE_FAIL=0

[ -d "$SB/taskflow" ] || { echo "== sandbox absent — materializing =="; "$HERE/setup-sandbox.sh" "$SB"; }

BIN=""; for c in st smalltalk; do command -v "$c" >/dev/null 2>&1 && { BIN="$c"; break; }; done
[ -z "$BIN" ] && { echo "no smalltalk CLI on PATH"; exit 1; }
c() { local who="$1"; shift; env ST_ROOT="$STR" ST_AGENT="$who" "$BIN" "$@"; }

echo "team-standup P4 · CLI=$BIN · sandbox=$SB"

# ── P4a: the CoS dry-run-launches the specialist in ITS repo ──────────────────
gate "P4a — CoS stands up a specialist (launch generates a bootable, correctly-identified harness)"
mkdir -p "$STR/$SPEC/inbox" "$STR/$SPEC/archive"   # same mkdir-first friction bootstrap flags
DRY=$( cd "$SB/taskflow" && c cos launch claude --identity "$SPEC" --dry-run 2>&1 )
if printf '%s\n' "$DRY" | grep -q "ST_AGENT = \"$SPEC\""; then
  pass "launch writes the CHILD's identity (ST_AGENT = \"$SPEC\") — HB-3 mitigated (ST_AGENT wins over an inherited launcher identity)"
else
  fail "launch pty.toml does not set the child's ST_AGENT — HB-3 identity-leak risk"
fi
printf '%s\n' "$DRY" | grep -q 'asyncRewake' \
  && pass "launch wires the SessionStart asyncRewake boot-ritual hook" \
  || note "launch did not wire the asyncRewake hook — the specialist won't self-boot on cold start"

# ── P4b: the CoS records the specialist in team.md (roster bookkeeping) ────────
gate "P4b — CoS records the stood-up specialist in team.md (lazy, on first work)"
# The standup step says: after spinning + briefing, record the specialist under ## agents in team.md.
# Simulate the CoS doing that bookkeeping (in P5 the live CoS does it itself).
TEAM="$SB/cos/team.md"
if grep -qiE '^\-\s*'"$SPEC" "$TEAM"; then
  pass "team.md already lists $SPEC"
else
  # append under the ## agents section, preserving the rest (merge, don't clobber)
  awk -v spec="$SPEC" '
    { print }
    /^## agents/ { print "- " spec " — owns the taskflow repo (stood up on first work)" }
  ' "$TEAM" > "$TEAM.tmp" && mv "$TEAM.tmp" "$TEAM"
  grep -qiE '^\-\s*'"$SPEC"'\b' "$TEAM" \
    && pass "recorded $SPEC under ## agents in team.md (roster now reflects the stood-up specialist)" \
    || fail "could not record $SPEC in team.md"
fi
# the roster must still carry the pre-existing projects/people (merge, not clobber)
grep -qi 'taskflow-web' "$TEAM" && grep -qi 'Sam Ortiz' "$TEAM" \
  && pass "team.md kept its projects + people (recording merged, didn't clobber)" \
  || fail "team.md lost a pre-existing section (bookkeeping clobbered the roster)"

# ── P4c: isolation precondition — the CoS owns no repo ────────────────────────
gate "P4c — isolation precondition (CoS owns no repo; specialist owns taskflow)"
[ -d "$SB/cos/.git" ] && fail "CoS dir IS a git repo (must own none)" || pass "CoS dir is not a git repo (structural isolation — cannot commit to taskflow)"
[ -d "$SB/taskflow/.git" ] && pass "taskflow is a git repo owned by $SPEC (author $SPEC@eval.local)" || fail "taskflow is not a git repo"

# ── summary ───────────────────────────────────────────────────────────────────
printf '\n─────────────────────────────────────────────\n'
[ "$GATE_FAIL" -eq 0 ] && printf 'P4 VERDICT: PASS — the CoS can stand up a correctly-wired specialist + track it in the roster.\n' \
                        || printf 'P4 VERDICT: FAIL — a mechanic failed (see ✗ above).\n'
printf 'NEXT: P5 (spin.sh) — the live proof: CoS delegates a real task, %s does it + reports, CoS walks it.\n' "$SPEC"
printf 'FRICTION (standup mechanics): %d\n' "${#FRICTION[@]}"
i=1; for f in "${FRICTION[@]}"; do printf '  %d. %s\n' "$i" "$f"; i=$((i+1)); done
printf '─────────────────────────────────────────────\n'
exit "$GATE_FAIL"
