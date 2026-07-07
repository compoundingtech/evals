#!/usr/bin/env bash
# Spin the DING-MODE (no-MCP participation) Claude cell via the REAL `st launch claude --ding`: BOTH agents
# join the network WITHOUT MCP — dm-sup (bypass, coordinate-only) + dm-dev (auto, owns widget), each with an
# `st ding` sidecar for inbox delivery + the `st` CLI for all bus ops. Run AFTER setup-sandbox.sh (auto-materializes).
#
# SELF-ISOLATING: creates + exports an isolated bus root ($SB/st-root); st launch bakes it into every session's
# env (agent + ding) so nothing touches the operator's live network.
#
#   ./spin.sh [SANDBOX]        # sandbox defaults to ${EVAL_SANDBOX:-./.sandbox}/ding-mode
#   needs: PERSONAS_DIR (bin/ensure-personas.sh provisions it). No external ST_ROOT / ST_HOOKS_DIR needed.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/../../../bin/lib-harness.sh"
SB="${1:-${EVAL_SANDBOX:-./.sandbox}/ding-mode}"
STR="$SB/st-root"                                    # SELF-ISOLATED bus root (never the live network)
export ST_ROOT="$STR"; export COORD_ROOT="$STR"      # st-launched agents + ding sidecars inherit these
stev_init "$(basename "$(dirname "$HERE")")" "$SB"   # per-run id + decoupled short PTY_ROOT
export PTY_ROOT="$(stev_pty_root "$SB")"             # stev-retirement: st launch honors this verbatim (#69) -> every session in the run's isolated pty root
stev_arm_teardown "$SB"                              # trap: teardown on crash/interrupt/early-exit

[ -d "$SB/widget" ] || { echo "== sandbox absent — materializing =="; "$HERE/setup-sandbox.sh" "$SB"; }
mkdir -p "$STR/dm-sup/inbox" "$STR/dm-sup/archive"   # so the kick can land before dm-sup launches

echo "== 1/4  compose ding-mode personas (bus contract now auto-installed by --ding as DING-BUS.md, #61) =="
"$HERE/compose-persona.sh" sup "$SB"
"$HERE/compose-persona.sh" dev "$SB"

echo "== 2/4  launch the worker first (st launch claude --ding: dm-dev, auto, owns widget, NO MCP) =="
"$HERE/configure-claude-agent.sh" dev "$SB"

echo "== 3/4  seed the hermetic kick into dm-sup's inbox (boot-time ms; strip HTML header) =="
ms=$(( $(date +%s) * 1000 ))
sfx="$(printf '%06x' "$(( (RANDOM << 8 ^ RANDOM) & 0xffffff ))")"
sed -n '/^---$/,$p' "$HERE/kick-supervisor.md" > "$STR/dm-sup/inbox/${ms}-${sfx}.md"
echo "   seeded $STR/dm-sup/inbox/${ms}-${sfx}.md"

echo "== 4/4  launch the supervisor last (st launch claude --ding: dm-sup, bypass, coordinate-only, NO MCP) =="
"$HERE/configure-claude-agent.sh" sup "$SB"

echo
echo "SPUN (Ding-mode cell, isolated bus at $STR). sessions (agents + ding sidecars):"
pty --root "$PTY_ROOT" ls 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g' | grep -E 'dm-sup|dm-dev' || pty --root "$PTY_ROOT" ls 2>/dev/null
echo
echo "OBSERVE the bus (ST_ROOT=$STR) — a fully NO-MCP loop: dm-sup boot-drains the kick via the st CLI ->"
echo "  delegates to dm-dev over the bus -> dm-dev gets a [DING], reads via CLI, implements slugify + commits +"
echo "  reports -> dm-sup verifies read-only -> confirms to eval-runner. Inbound = [DING] pokes; all ops = st CLI."
echo "WATCH: the ding sidecars deliver; peek a session: pty --root $PTY_ROOT tail dm-dev-run 2>/dev/null || true"
echo
echo "GRADE after the loop settles:  $HERE/grade.sh \"$SB\""
echo "TEARDOWN after grading:        bin/st-evals teardown \"$SB\"   (zero-orphan incl. the ding sidecars)"
