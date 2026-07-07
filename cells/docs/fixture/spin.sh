#!/usr/bin/env bash
# Spin the Docs (explain-it) Claude cell via the REAL `st launch`: doc-sup (bypass, coordinate-only) +
# doc-writer (auto, owns the checkout repo). Run AFTER setup-sandbox.sh (auto-materializes if the sandbox
# is absent). SELF-ISOLATING: creates + exports an isolated bus root ($SB/st-root) so nothing touches the
# operator's live network — the st-launched agents inherit ST_ROOT/COORD_ROOT from this process (RISK 2).
# Composes personas (standalone files for --persona), launches worker first + supervisor last, and seeds
# the hermetic docs request into doc-sup's inbox. Claude agents auto-wake via st launch's asyncRewake hook.
# After the team reports, grade the docs held-out with cold-reader.sh (a fresh docs-only agent) + grade.sh.
#
#   ./spin.sh [SANDBOX]        # sandbox defaults to ${EVAL_SANDBOX:-./.sandbox}/docs
#   needs: PERSONAS_DIR (bin/ensure-personas.sh provisions it). No external ST_ROOT / ST_HOOKS_DIR needed —
#          spin owns the isolated root and st launch wires its own boot hooks.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/../../../bin/lib-harness.sh"
SB="${1:-${EVAL_SANDBOX:-./.sandbox}/docs}"
STR="$SB/st-root"                                    # SELF-ISOLATED bus root (never the live network)
export ST_ROOT="$STR"; export COORD_ROOT="$STR"      # st-launched agents inherit these -> isolated bus
stev_init "$(basename "$(dirname "$HERE")")" "$SB"   # per-run id + decoupled short PTY_ROOT
export PTY_ROOT="$(stev_pty_root "$SB")"             # stev-retirement: st launch honors this verbatim (#69) -> every session in the run's isolated pty root
stev_arm_teardown "$SB"                              # trap: teardown on crash/interrupt/early-exit

[ -d "$SB/worker" ] || { echo "== sandbox absent — materializing =="; "$HERE/setup-sandbox.sh" "$SB"; }
mkdir -p "$STR/doc-sup/inbox" "$STR/doc-sup/archive"   # so the kick can land before doc-sup launches

echo "== 1/4  compose personas (standalone files for st launch --persona) =="
"$HERE/compose-persona.sh" sup "$SB"
"$HERE/compose-persona.sh" writer "$SB"

echo "== 2/4  launch the worker first (st launch: doc-writer, auto, owns checkout) =="
"$HERE/configure-claude-agent.sh" writer "$SB"

echo "== 3/4  seed the hermetic docs request into doc-sup's inbox (boot-time ms; strip HTML header) =="
ms=$(( $(date +%s) * 1000 ))
sfx="$(printf '%06x' "$(( (RANDOM << 8 ^ RANDOM) & 0xffffff ))")"
sed -n '/^---$/,$p' "$HERE/kick-supervisor.md" > "$STR/doc-sup/inbox/${ms}-${sfx}.md"
echo "   seeded $STR/doc-sup/inbox/${ms}-${sfx}.md"

echo "== 4/4  launch the supervisor last (st launch: doc-sup, bypass, coordinate-only) =="
"$HERE/configure-claude-agent.sh" sup "$SB"

echo
echo "SPUN (Docs cell, isolated bus at $STR). sessions:"
pty --root "$PTY_ROOT" ls 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g' | grep -E 'doc-sup|doc-writer' || pty --root "$PTY_ROOT" ls 2>/dev/null
echo
echo "OBSERVE the coord thread (ST_ROOT=$STR): request -> doc-sup delegate -> doc-writer read code+tests ->"
echo "  write README/docs (surface the 3 gotchas) -> commit -> report -> doc-sup read-only verify (accurate?"
echo "  complete? cold-usable? src unchanged? suite green?) -> confirm to eval-runner."
echo "WAKE: Claude auto-wakes via st launch's asyncRewake hook. If an agent idles on a delivered message, poke"
echo "  by hand (a tracked HB-4 poke): pty send <session> --with-delay 0.4 --seq key:ctrl+u --seq 'read your inbox and proceed' --seq key:return"
echo
echo "THEN grade held-out: fixture/cold-reader.sh (fresh docs-only agent computes a total) + fixture/grade.sh"
echo "TEARDOWN after grading:  bin/st-evals teardown \"$SB\""
