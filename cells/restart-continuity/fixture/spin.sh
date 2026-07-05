#!/usr/bin/env bash
# Spin the Restart-continuity (durability) Claude cell via the REAL `st launch`: rc-sup (bypass,
# coordinate-only) + rc-dev (auto, owns ledger). Then background the SCRIPTED FAULT INJECTION —
# restart-injector.sh cold-restarts rc-dev after item 2 lands. Run AFTER setup-sandbox.sh
# (auto-materializes if the sandbox is absent).
#
# SELF-ISOLATING: creates + exports an isolated bus root ($SB/st-root); the st-launched agents (and the
# injector's cold relaunch) inherit ST_ROOT/COORD_ROOT — nothing touches the operator's live network.
#
#   ./spin.sh [SANDBOX]        # sandbox defaults to ${EVAL_SANDBOX:-./.sandbox}/restart-continuity
#   needs: PERSONAS_DIR (bin/ensure-personas.sh provisions it). No external ST_ROOT / ST_HOOKS_DIR needed.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/../../../bin/lib-harness.sh"
SB="${1:-${EVAL_SANDBOX:-./.sandbox}/restart-continuity}"
STR="$SB/st-root"                                    # SELF-ISOLATED bus root (never the live network)
export ST_ROOT="$STR"; export COORD_ROOT="$STR"      # st-launched agents + the injector inherit these
stev_init "$(basename "$(dirname "$HERE")")" "$SB"   # per-run collision-proof pty prefix
stev_arm_teardown "$SB"                              # trap: teardown on crash/interrupt/early-exit

[ -d "$SB/ledger" ] || { echo "== sandbox absent — materializing =="; "$HERE/setup-sandbox.sh" "$SB"; }
mkdir -p "$STR/rc-sup/inbox" "$STR/rc-sup/archive"   # so the kick can land before rc-sup launches

echo "== 1/5  compose personas (standalone files for st launch --persona) =="
"$HERE/compose-persona.sh" sup "$SB"
"$HERE/compose-persona.sh" dev "$SB"

echo "== 2/5  launch the worker first (st launch: rc-dev, auto, owns ledger) =="
"$HERE/configure-claude-agent.sh" dev "$SB"

echo "== 3/5  seed the hermetic kick into rc-sup's inbox (boot-time ms; strip HTML header) =="
ms=$(( $(date +%s) * 1000 ))
sfx="$(printf '%06x' "$(( (RANDOM << 8 ^ RANDOM) & 0xffffff ))")"
sed -n '/^---$/,$p' "$HERE/kick-supervisor.md" > "$STR/rc-sup/inbox/${ms}-${sfx}.md"
echo "   seeded $STR/rc-sup/inbox/${ms}-${sfx}.md"

echo "== 4/5  launch the supervisor last (st launch: rc-sup, bypass, coordinate-only) =="
"$HERE/configure-claude-agent.sh" sup "$SB"

echo "== 5/5  arm the fault injection (background: cold-restart rc-dev after item 2 lands) =="
mkdir -p "$SB/.stev"
nohup "$HERE/restart-injector.sh" "$SB" >> "$SB/.stev/injector.out" 2>&1 &
disown 2>/dev/null || true
echo "   restart-injector backgrounded (pid $!); log: $SB/.stev/injector.out ; event log: $SB/.stev/restart.log"

echo
echo "SPUN (Restart-continuity cell, isolated bus at $STR). sessions:"
pty ls 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g' | grep -E "$(stev_run_prefix "$SB")|rc-sup-|rc-dev-" || pty ls
echo
echo "OBSERVE the coord thread (ST_ROOT=$STR): kick -> rc-sup delegate -> rc-dev process items 1..4 (per-item"
echo "  commit) -> [INJECTED: cold restart of rc-dev after item 2] -> rc-dev resumes items 3..4 -> report ->"
echo "  rc-sup verify (every item done? suite green?) -> confirm to eval-runner."
echo "WATCH: tail -f $SB/.stev/injector.out   (the fault injection);   git -C $SB/ledger log --oneline"
echo "WAKE: Claude auto-wakes via st launch's asyncRewake hook (incl. the cold-restarted session)."
echo
echo "GRADE after the batch settles:  $HERE/grade.sh \"$SB\""
echo "TEARDOWN after grading:         bin/st-evals teardown \"$SB\"   (zero-orphan incl. the relaunched session)"
