#!/usr/bin/env bash
# Spin the DING-REPLY cell (NO MCP) via REAL convoy (`convoy add`, ding-default): a SINGLE agent (dr-agent)
# receives a message via its `st ding` sidecar and must REPLY on the thread over the `st` CLI (`st message
# reply`) — the exact path the reply bug slipped through. SELF-ISOLATING: `convoy init`s an isolated network
# at $SB/st-root so nothing touches the live convoy; convoy add lands the agent + ding sidecar under $NET/pty.
#   ./spin.sh [SANDBOX]        # sandbox defaults to ${EVAL_SANDBOX:-./.sandbox}/ding-reply
#   needs: PERSONAS_DIR (bin/ensure-personas.sh provisions it).
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/../../../bin/lib-harness.sh"
SB="${1:-${EVAL_SANDBOX:-./.sandbox}/ding-reply}"
NET="$SB/st-root"; export ST_ROOT="$NET"            # SELF-ISOLATED convoy network (never the live one)

[ -f "$SB/work/ANSWER.txt" ] || { echo "== sandbox absent — materializing =="; "$HERE/setup-sandbox.sh" "$SB"; }

STEV_NET="$NET"
trap 'rc=$?; [ "$rc" = 0 ] || { echo "== spin rc=$rc — tearing down the isolated net ==" >&2; stev_convoy_teardown "$STEV_NET"; }' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

echo "== 1/4  convoy init the isolated network ($NET) =="
stev_convoy_init "$NET"

echo "== 2/4  compose persona (ding-mode, no MCP; convoy add installs the bus contract as DING-BUS.md) =="
"$HERE/compose-persona.sh" "$SB" >/dev/null

echo "== 3/4  launch the agent (convoy add: dr-agent, auto, ding/no-MCP) — creates its inbox + ding sidecar =="
"$HERE/configure-claude-agent.sh" "$SB"
mkdir -p "$NET/dr-req/inbox" "$NET/dr-req/archive"   # fake requester: so the agent's reply has somewhere to land

echo "== 4/4  seed the requester's kick into dr-agent's inbox (the message it must REPLY to) =="
mkdir -p "$SB/.stev"
# deliver over the REAL bus; stev_seed_kick returns the delivered filename (grader needs it for in-reply-to)
kickfn="$(stev_seed_kick "$NET" "dr-agent" "$HERE/kick.md")"
printf '%s\n' "$kickfn" > "$SB/.stev/kick-filename"   # grader asserts the reply's in-reply-to == this
echo "   delivered kick -> dr-agent ($kickfn)"

echo
echo "SPUN (ding-reply, isolated convoy net $NET). members:"; convoy ls "$NET" 2>/dev/null | grep -E 'dr-agent' || convoy ls "$NET" 2>/dev/null
echo "OBSERVE (ST_ROOT=$NET): dr-agent boots via ding (no MCP) -> reads the kick over the st CLI -> reads"
echo "  work/ANSWER.txt -> REPLIES ON THE THREAD via 'st message reply' (recipient dr-req derived from the kick)."
echo "  The reply must land in dr-req's inbox with in-reply-to = the kick + carry the ANSWER.txt token."
echo "GRADE when settled:  $HERE/grade.sh \"$SB\""
echo "TEARDOWN:            convoy down \"$NET\"   (then rm -rf \"$SB\")"
