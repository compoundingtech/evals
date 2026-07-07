#!/usr/bin/env bash
# Spin the signal-rename cell via the REAL `st launch`: sig-sup (bypass, integration lead, owns app.toml) +
# sig-base / sig-relay / sig-hub (auto, one product repo each). Run AFTER setup-sandbox.sh (auto-materializes if
# absent). SELF-ISOLATING: creates + exports an isolated COORDINATION bus root ($SB/st-root) so nothing touches
# the operator's live network; the st-launched agents inherit ST_ROOT/COORD_ROOT from this process. Launches the
# specialists FIRST + the supervisor LAST (so the sup boots to a seeded inbox, not an empty one), and seeds the
# hermetic rename request into sig-sup's inbox. Claude agents auto-wake via st launch's asyncRewake hook.
#
#   ./spin.sh [SANDBOX]     # default: ${EVAL_SANDBOX:-./.sandbox}/signal-rename
#   needs: PERSONAS_DIR (bin/ensure-personas.sh provisions it). No external ST_ROOT / ST_HOOKS_DIR needed —
#          spin owns the isolated root and st launch wires its own boot hooks.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/../../../bin/lib-harness.sh"
SB="${1:-${EVAL_SANDBOX:-./.sandbox}/signal-rename}"
STR="$SB/st-root"                                    # SELF-ISOLATED coordination bus (never the live network)
export ST_ROOT="$STR"; export COORD_ROOT="$STR"      # st-launched agents inherit these -> isolated bus
stev_init "$(basename "$(dirname "$HERE")")" "$SB"   # per-run id + decoupled short PTY_ROOT
export PTY_ROOT="$(stev_pty_root "$SB")"             # stev-retirement: st launch honors this verbatim (#69) -> every session in the run's isolated pty root
stev_arm_teardown "$SB"                              # trap: teardown on crash/interrupt/early-exit

[ -d "$SB/base" ] || { echo "== sandbox absent — materializing =="; "$HERE/setup-sandbox.sh" "$SB"; }
mkdir -p "$STR/sig-sup/inbox" "$STR/sig-sup/archive"  # so the kick can land before sig-sup launches

echo "== 1/4  compose personas (standalone files for st launch --persona) =="
for r in sup base relay hub; do "$HERE/compose-persona.sh" "$r" "$SB" >/dev/null && echo "   composed sig-$r"; done

echo "== 2/4  launch the specialists first (st launch: base/relay/hub, auto) =="
for r in base relay hub; do "$HERE/configure-claude-agent.sh" "$r" "$SB"; done

echo "== 3/4  seed the hermetic rename request into sig-sup's inbox (boot-time ms; strip HTML header) =="
ms=$(( $(date +%s) * 1000 ))
sfx="$(printf '%06x' "$(( (RANDOM << 8 ^ RANDOM) & 0xffffff ))")"
sed -n '/^---$/,$p' "$HERE/kick-supervisor.md" > "$STR/sig-sup/inbox/${ms}-${sfx}.md"
echo "   seeded $STR/sig-sup/inbox/${ms}-${sfx}.md"

echo "== 4/4  launch the supervisor last (st launch: sig-sup, bypass, integration lead) =="
"$HERE/configure-claude-agent.sh" sup "$SB"

echo
echo "SPUN (signal-rename cell, isolated bus at $STR). sessions:"
pty --root "$PTY_ROOT" ls 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g' | grep -E 'sig-(sup|base|relay|hub)' || pty --root "$PTY_ROOT" ls 2>/dev/null || true
echo
echo "OBSERVE the coord thread: sig-sup sequences the cutover — briefs sig-base to rename @acme/signal->@acme/beacon"
echo "  (+ the bin) FIRST with a compat/alias window; sig-base signals the consumers; then sig-relay + sig-hub bump"
echo "  peerDep + imports (+ signal://->beacon:// for the hub), each keeping node --test GREEN and the PRIMITIVE"
echo "  (AbortSignal/SIGTERM) intact; sig-sup renames app.toml + integrates + reports to the requester (morgan)."
echo
echo "GRADE when the rename closes:  fixture/grade.sh \"$SB\""
echo "TEARDOWN after grading:  bin/st-evals teardown \"$SB\""
