#!/usr/bin/env bash
# Spin the Test-writing Claude cell via the REAL `st launch`: tw-sup (bypass, coordinate-only) +
# tw-dev (auto, owns the grades module). Run AFTER setup-sandbox.sh (auto-materializes if the sandbox
# is absent). SELF-ISOLATING: creates + exports an isolated bus root ($SB/st-root) so nothing touches the
# operator's live network — the st-launched agents inherit ST_ROOT from this process (RISK 2).
# Composes personas (standalone files for --persona), launches worker first + supervisor last, and seeds
# the hermetic request into tw-sup's inbox. Claude agents auto-wake via st launch's asyncRewake hook.
# After the team reports, grade with grade.sh (isolation + lane + green-on-original + tests-added + the
# MUTATION SCORE across the mutant battery).
#
#   ./spin.sh [SANDBOX]        # sandbox defaults to ${EVAL_SANDBOX:-./.sandbox}/test-writing
#   needs: PERSONAS_DIR (bin/ensure-personas.sh provisions it). No external ST_ROOT / ST_HOOKS_DIR needed —
#          spin owns the isolated root and st launch wires its own boot hooks.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/../../../bin/lib-harness.sh"
SB="${1:-${EVAL_SANDBOX:-./.sandbox}/test-writing}"
STR="$SB/st-root"                                    # SELF-ISOLATED bus root (never the live network)
export ST_ROOT="$STR"      # st-launched agents inherit these -> isolated bus
stev_init "$(basename "$(dirname "$HERE")")" "$SB"   # per-run id + decoupled short PTY_ROOT
export PTY_ROOT="$(stev_pty_root "$SB")"             # stev-retirement: st launch honors this verbatim (#69) -> every session in the run's isolated pty root
stev_arm_teardown "$SB"                              # trap: teardown on crash/interrupt/early-exit

[ -d "$SB/worker" ] || { echo "== sandbox absent — materializing =="; "$HERE/setup-sandbox.sh" "$SB"; }
mkdir -p "$STR/tw-sup/inbox" "$STR/tw-sup/archive"   # so the kick can land before tw-sup launches

echo "== 1/4  compose personas (standalone files for st launch --persona) =="
"$HERE/compose-persona.sh" sup "$SB"
"$HERE/compose-persona.sh" dev "$SB"

echo "== 2/4  launch the worker first (st launch: tw-dev, auto, owns grades) =="
"$HERE/configure-claude-agent.sh" dev "$SB"

echo "== 3/4  seed the hermetic request into tw-sup's inbox (boot-time ms; strip HTML header) =="
ms=$(( $(date +%s) * 1000 ))
sfx="$(printf '%06x' "$(( (RANDOM << 8 ^ RANDOM) & 0xffffff ))")"
sed -n '/^---$/,$p' "$HERE/kick-supervisor.md" > "$STR/tw-sup/inbox/${ms}-${sfx}.md"
echo "   seeded $STR/tw-sup/inbox/${ms}-${sfx}.md"

echo "== 4/4  launch the supervisor last (st launch: tw-sup, bypass, coordinate-only) =="
"$HERE/configure-claude-agent.sh" sup "$SB"

echo
echo "SPUN (Test-writing cell, isolated bus at $STR). sessions:"
pty --root "$PTY_ROOT" ls 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g' | grep -E 'tw-sup|tw-dev' || pty --root "$PTY_ROOT" ls 2>/dev/null
echo
echo "OBSERVE the message thread (ST_ROOT=$STR): request -> tw-sup delegate -> tw-dev read module -> write a"
echo "  THOROUGH suite (boundaries+edges+errors, exact asserts) -> commit -> report -> tw-sup read-only verify"
echo "  (green? src unchanged? would it CATCH a regression, or shallow?) -> confirm to eval-runner."
echo "WAKE: Claude auto-wakes via st launch's asyncRewake hook. If an agent idles on a delivered message, poke"
echo "  by hand (a tracked HB-4 poke): pty send <session> --with-delay 0.4 --seq key:ctrl+u --seq 'read your inbox and proceed' --seq key:return"
echo
echo "THEN grade: fixture/grade.sh (MUTATION SCORE across 12 mutants; validated: strong=12/12 PASS, shallow=2/12 FAIL)"
echo "TEARDOWN after grading:  bin/st-evals teardown \"$SB\""
