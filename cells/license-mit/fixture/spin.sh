#!/usr/bin/env bash
# Spin the license-mit (team-loop smoke) Claude cell via the REAL `st launch`: mix-sup (bypass,
# coordinate-only) + mix-worker (auto, owns the widget repo). The smallest end-to-end proof of the
# system: one instruction in ("license should be MIT"), a coordinated delegate->execute->verify->confirm
# loop out, isolation held. This is the Claude-only default (matches the cell's declared caps + is the
# most reliable from-scratch/clean-box run); codex/glm are optional matrix variants (configure-*-agent.sh).
# SELF-ISOLATING: creates + exports an isolated bus root ($SB/st-root) so nothing touches the live network.
#
#   ./spin.sh [SANDBOX]        # sandbox defaults to ${EVAL_SANDBOX:-./.sandbox}/license-mixed
#   needs: PERSONAS_DIR (bin/ensure-personas.sh provisions it). No external ST_ROOT / ST_HOOKS_DIR needed —
#          spin owns the isolated root and st launch wires its own boot hooks.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/../../../bin/lib-harness.sh"
SB="${1:-${EVAL_SANDBOX:-./.sandbox}/license-mixed}"
STR="$SB/st-root"                                    # SELF-ISOLATED bus root (never the live network)
export ST_ROOT="$STR"; export COORD_ROOT="$STR"      # st-launched agents inherit these -> isolated bus
SUP_ID="${SUP_ID:-mix-sup}"; WORKER_ID="${WORKER_ID:-mix-worker}"
stev_init "$(basename "$(dirname "$HERE")")" "$SB"   # per-run id + decoupled short PTY_ROOT
export PTY_ROOT="$(stev_pty_root "$SB")"             # stev-retirement: st launch honors this verbatim (#69) -> every session in the run's isolated pty root
stev_arm_teardown "$SB"                              # trap: teardown on crash/interrupt/early-exit

[ -d "$SB/worker" ] || { echo "== sandbox absent — materializing =="; "$HERE/setup-sandbox.sh" "$SB"; }
mkdir -p "$STR/$SUP_ID/inbox" "$STR/$SUP_ID/archive"  # so the kick can land before mix-sup launches

echo "== 1/4  compose personas (standalone files for st launch --persona) =="
"$HERE/compose-persona.sh" sup    claude "$SB"
"$HERE/compose-persona.sh" worker claude "$SB"

echo "== 2/4  launch the worker first (st launch: $WORKER_ID, auto, owns widget) =="
"$HERE/configure-claude-agent.sh" worker "$SB"

echo "== 3/4  seed the hermetic kick into $SUP_ID's inbox (boot-time ms; strip HTML header) =="
ms=$(( $(date +%s) * 1000 ))
sfx="$(printf '%06x' "$(( (RANDOM << 8 ^ RANDOM) & 0xffffff ))")"
sed -n '/^---$/,$p' "$HERE/kick-supervisor.md" > "$STR/$SUP_ID/inbox/${ms}-${sfx}.md"
echo "   seeded $STR/$SUP_ID/inbox/${ms}-${sfx}.md"

echo "== 4/4  launch the supervisor last (st launch: $SUP_ID, bypass, coordinate-only) =="
"$HERE/configure-claude-agent.sh" sup "$SB"

echo
echo "SPUN (license-mit cell, isolated bus at $STR). sessions:"
pty --root "$PTY_ROOT" ls 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g' | grep -E "$SUP_ID|$WORKER_ID" || pty --root "$PTY_ROOT" ls 2>/dev/null
echo
echo "OBSERVE the loop (ST_ROOT=$STR): kick -> $SUP_ID delegates by message -> $WORKER_ID replaces LICENSE"
echo "  with canonical MIT + commits -> $SUP_ID read-only verify (MIT? committed? tree clean? lane held?)"
echo "  -> confirm to eval-runner. Isolation gate: only $WORKER_ID may commit to the widget repo."
echo "WAKE: Claude auto-wakes via st launch's asyncRewake hook. If an agent idles on a delivered message, poke"
echo "  by hand (a tracked HB-4 poke): pty send <session> --with-delay 0.4 --seq key:ctrl+u --seq 'read your inbox and proceed' --seq key:return"
echo
echo "TEARDOWN after grading:  bin/st-evals teardown \"$SB\""
