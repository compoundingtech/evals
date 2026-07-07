#!/usr/bin/env bash
# Spin the tui-build cell via the REAL `st launch`: tui-sup (bypass, integration lead) + tui-tree /
# tui-cards (auto, own a view each) + tui-ux (auto, usability reviewer, no code). Run AFTER setup-sandbox.sh
# (auto-materializes if the sandbox is absent). SELF-ISOLATING: creates + exports an isolated COORDINATION
# bus root ($SB/st-root) so nothing touches the operator's live network; the st-launched agents inherit
# ST_ROOT/COORD_ROOT from this process (RISK 2). Composes personas (standalone files for --persona),
# launches the workers first + supervisor last, and seeds the hermetic build request into tui-sup's inbox.
# Claude agents auto-wake via st launch's asyncRewake hook.
# TWO ROOTS (do not conflate): $SB/st-root is the COORDINATION bus (where the team talks). The viz they BUILD
# reads its DATA from the FROZEN fixture ($SB/fixture/smalltalk) — a separate root the personas pass explicitly.
#
#   ./spin.sh [SANDBOX]     # default: ${EVAL_SANDBOX:-./.sandbox}/tui-build
#   needs: PERSONAS_DIR (bin/ensure-personas.sh provisions it). No external ST_ROOT / ST_HOOKS_DIR needed —
#          spin owns the isolated root and st launch wires its own boot hooks.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/../../../bin/lib-harness.sh"
SB="${1:-${EVAL_SANDBOX:-./.sandbox}/tui-build}"
STR="$SB/st-root"                                    # SELF-ISOLATED coordination bus (never the live network)
export ST_ROOT="$STR"; export COORD_ROOT="$STR"      # st-launched agents inherit these -> isolated bus
stev_init "$(basename "$(dirname "$HERE")")" "$SB"   # per-run id + decoupled short PTY_ROOT
export PTY_ROOT="$(stev_pty_root "$SB")"             # stev-retirement: st launch honors this verbatim (#69) -> every session in the run's isolated pty root
stev_arm_teardown "$SB"                              # trap: teardown on crash/interrupt/early-exit

[ -d "$SB/sup" ] || { echo "== sandbox absent — materializing =="; "$HERE/setup-sandbox.sh" "$SB"; }
mkdir -p "$STR/tui-sup/inbox" "$STR/tui-sup/archive"  # so the kick can land before tui-sup launches

echo "== 1/4  compose personas (standalone files for st launch --persona) =="
for r in sup tree cards ux; do "$HERE/compose-persona.sh" "$r" "$SB" >/dev/null && echo "   composed tui-$r"; done

echo "== 2/4  launch the workers first (st launch: tree/cards/ux, auto) =="
for r in tree cards ux; do "$HERE/configure-claude-agent.sh" "$r" "$SB"; done

echo "== 3/4  seed the hermetic build request into tui-sup's inbox (boot-time ms; strip HTML header) =="
ms=$(( $(date +%s) * 1000 ))
sfx="$(printf '%06x' "$(( (RANDOM << 8 ^ RANDOM) & 0xffffff ))")"
sed -n '/^---$/,$p' "$HERE/kick-supervisor.md" > "$STR/tui-sup/inbox/${ms}-${sfx}.md"
echo "   seeded $STR/tui-sup/inbox/${ms}-${sfx}.md"

echo "== 4/4  launch the supervisor last (st launch: tui-sup, bypass, integration lead) =="
"$HERE/configure-claude-agent.sh" sup "$SB"

echo
echo "SPUN (tui-build cell, isolated bus at $STR). sessions:"
pty --root "$PTY_ROOT" ls 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g' | grep -E 'tui-(sup|tree|cards|ux)' || pty --root "$PTY_ROOT" ls 2>/dev/null || true
echo
echo "OBSERVE the coord thread: tui-sup builds the shared data layer (src/data/network.ts -> coord agents"
echo "  --enrich --json, read-only) -> briefs tui-tree + tui-cards to wire their views to it -> briefs"
echo "  tui-ux for the usability pass -> integrates -> drives the find->fix loop (ux finds, the view owner"
echo "  fixes, re-verify) -> reports to river. The built viz reads the FROZEN fixture (a SEPARATE root):"
echo "     ST_ROOT=$SB/fixture/smalltalk npm start   (and npm run cards)"
echo
echo "WAKE: Claude auto-wakes via st launch's asyncRewake hook. If an agent idles on a delivered message,"
echo "  poke by hand (a tracked HB-4 poke): pty send <session> --with-delay 0.4 --seq key:ctrl+u --seq 'read your inbox and proceed' --seq key:return"
echo
echo "GRADE when the build closes:  fixture/grade.sh \"$SB\""
echo "TEARDOWN after grading:  bin/st-evals teardown \"$SB\""
