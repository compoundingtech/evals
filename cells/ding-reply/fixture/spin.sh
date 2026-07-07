#!/usr/bin/env bash
# Spin the DING-REPLY cell (NO MCP — the MCP-less config) via the REAL `st launch claude --ding`: a SINGLE agent
# receives a message via ding and must REPLY on the thread over the `st` CLI (`st message reply`). That CLI reply
# verb is the exact path the reply bug slipped through — this cell exercises + asserts it end-to-end.
#
# SELF-ISOLATING: creates + exports an isolated bus root ($SB/st-root); st launch bakes it into the agent + ding
# sidecar env so nothing touches the operator's live network.
#   ./spin.sh [SANDBOX]        # sandbox defaults to ${EVAL_SANDBOX:-./.sandbox}/ding-reply
#   needs: PERSONAS_DIR (bin/ensure-personas.sh provisions it).
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/../../../bin/lib-harness.sh"
SB="${1:-${EVAL_SANDBOX:-./.sandbox}/ding-reply}"
STR="$SB/st-root"                                    # SELF-ISOLATED bus root (never the live network)
export ST_ROOT="$STR"; export COORD_ROOT="$STR"      # the st-launched agent + ding sidecar inherit these
stev_init "$(basename "$(dirname "$HERE")")" "$SB"   # per-run id + decoupled short PTY_ROOT
export PTY_ROOT="$(stev_pty_root "$SB")"             # st launch honors this verbatim (#69) -> every session in the run's pty root
stev_arm_teardown "$SB"                              # trap: teardown on crash/interrupt/early-exit

[ -f "$SB/work/ANSWER.txt" ] || { echo "== sandbox absent — materializing =="; "$HERE/setup-sandbox.sh" "$SB"; }
mkdir -p "$STR/dr-agent/inbox" "$STR/dr-agent/archive"; printf 'available\n' > "$STR/dr-agent/status"
mkdir -p "$STR/dr-req/inbox"   "$STR/dr-req/archive"                     # so the agent's reply can land

echo "== compose persona (ding-mode, no MCP; bus contract auto-installed by --ding as DING-BUS.md) =="
"$HERE/compose-persona.sh" "$SB" >/dev/null

echo "== seed the requester's kick into dr-agent's inbox (the message it must REPLY to) =="
ms=$(( $(date +%s) * 1000 )); sfx="$(printf '%06x' "$(( (RANDOM << 8 ^ RANDOM) & 0xffffff ))")"
kickfn="${ms}-${sfx}.md"
sed -n '/^---$/,$p' "$HERE/kick.md" > "$STR/dr-agent/inbox/$kickfn"
printf '%s\n' "$kickfn" > "$SB/.stev/kick-filename"                     # the grader asserts the reply's in-reply-to == this
echo "   seeded $STR/dr-agent/inbox/$kickfn"

echo "== launch the agent (st launch claude --ding: dr-agent, auto, NO MCP) =="
"$HERE/configure-claude-agent.sh" "$SB"

echo
echo "SPUN (ding-reply, isolated bus $STR). sessions (agent + ding sidecar):"
pty --root "$PTY_ROOT" ls 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g' | grep -E 'dr-agent' || pty --root "$PTY_ROOT" ls 2>/dev/null
echo
echo "OBSERVE (ST_ROOT=$STR): dr-agent boots via ding (no MCP) -> reads the kick over the st CLI -> reads"
echo "  work/ANSWER.txt -> REPLIES ON THE THREAD via 'st message reply' (recipient dr-req derived from the kick)."
echo "  The reply must land in dr-req's inbox with in-reply-to = the kick + carry the ANSWER.txt token."
echo "GRADE when settled:  $HERE/grade.sh \"$SB\""
echo "TEARDOWN:            bin/st-evals teardown \"$SB\"   (zero-orphan incl. the ding sidecar)"
