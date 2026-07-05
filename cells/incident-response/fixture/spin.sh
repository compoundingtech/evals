#!/usr/bin/env bash
# Spin the Incident-response Claude cell via the REAL `st launch`: ir-sup (bypass, coordinate-only) +
# ir-oncall (auto, owns pulse). Run AFTER setup-sandbox.sh (auto-materializes if the sandbox is absent).
# SELF-ISOLATING: creates + exports an isolated bus root ($SB/st-root) so nothing touches the operator's
# live network — the st-launched agents inherit ST_ROOT/COORD_ROOT from this process (verified: RISK 2).
# Composes personas (standalone files for --persona), launches worker first + supervisor last, and seeds
# the hermetic incident page into ir-sup's inbox. Claude agents auto-wake via st launch's asyncRewake hook.
#
#   ./spin.sh [SANDBOX]        # sandbox defaults to ${EVAL_SANDBOX:-./.sandbox}/incident-response
#   needs: PERSONAS_DIR (bin/ensure-personas.sh provisions it). No external ST_ROOT / ST_HOOKS_DIR needed —
#          spin owns the isolated root and st launch wires its own boot hooks.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/../../../bin/lib-harness.sh"
SB="${1:-${EVAL_SANDBOX:-./.sandbox}/incident-response}"
STR="$SB/st-root"                                    # SELF-ISOLATED bus root (never the live network)
export ST_ROOT="$STR"; export COORD_ROOT="$STR"      # st-launched agents inherit these -> isolated bus
stev_init "$(basename "$(dirname "$HERE")")" "$SB"   # per-run collision-proof pty prefix
stev_arm_teardown "$SB"                              # trap: teardown on crash/interrupt/early-exit

[ -d "$SB/worker" ] || { echo "== sandbox absent — materializing =="; "$HERE/setup-sandbox.sh" "$SB"; }
mkdir -p "$STR/ir-sup/inbox" "$STR/ir-sup/archive"   # so the kick can land before ir-sup launches

echo "== 1/4  compose personas (standalone files for st launch --persona) =="
"$HERE/compose-persona.sh" sup "$SB"
"$HERE/compose-persona.sh" oncall "$SB"

echo "== 2/4  launch the worker first (st launch: ir-oncall, auto, owns pulse) =="
"$HERE/configure-claude-agent.sh" oncall "$SB"

echo "== 3/4  seed the hermetic incident page into ir-sup's inbox (boot-time ms; strip HTML header) =="
ms=$(( $(date +%s) * 1000 ))
sfx="$(printf '%06x' "$(( (RANDOM << 8 ^ RANDOM) & 0xffffff ))")"
sed -n '/^---$/,$p' "$HERE/kick-supervisor.md" > "$STR/ir-sup/inbox/${ms}-${sfx}.md"
echo "   seeded $STR/ir-sup/inbox/${ms}-${sfx}.md"

echo "== 4/4  launch the supervisor last (st launch: ir-sup, bypass, coordinate-only) =="
"$HERE/configure-claude-agent.sh" sup "$SB"

echo
echo "SPUN (Incident-response cell, isolated bus at $STR). sessions:"
pty ls 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g' | grep -E "$(stev_run_prefix "$SB")|ir-sup-|ir-oncall-" || pty ls
echo
echo "OBSERVE the coord thread (ST_ROOT=$STR): page -> ir-sup triage+delegate -> ir-oncall reproduce -> mitigate ->"
echo "  ROOT fix + regression test -> report -> ir-sup read-only verify (500 gone AND values correct? root cause"
echo "  fixed not masked? regression test real? suite green? lane held?) -> confirm to eval-runner."
echo "WAKE: Claude auto-wakes via st launch's asyncRewake hook. If an agent idles on a delivered message, poke"
echo "  by hand (a tracked HB-4 poke): pty send <session> --with-delay 0.4 --seq key:ctrl+u --seq 'read your inbox and proceed' --seq key:return"
echo
echo "TEARDOWN after grading:  bin/st-evals teardown \"$SB\""
