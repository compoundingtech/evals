#!/usr/bin/env bash
# Spin the tui-build cell via REAL convoy (ding-default, no MCP): tui-sup (bypass, integration lead) + tui-tree /
# tui-cards (auto, own a view each) + tui-ux (auto, usability reviewer, no code). Run AFTER setup-sandbox.sh
# (auto-materializes if the sandbox is absent). SELF-ISOLATING: `convoy init`s an isolated COORDINATION
# network at $SB/st-root so nothing touches the operator's live convoy — every session (agent + ding sidecar)
# lands under $NET/pty. Composes personas (standalone files for --persona), launches the workers first +
# supervisor last, THEN seeds the hermetic build request into tui-sup's inbox — its `st ding` sidecar
# (created by convoy add) delivers it.
# TWO ROOTS (do not conflate): $SB/st-root is the COORDINATION bus (where the team talks). The viz they BUILD
# reads its DATA from the FROZEN fixture ($SB/fixture/smalltalk) — a separate root the personas pass explicitly.
#
#   ./spin.sh [SANDBOX]     # default: ${EVAL_SANDBOX:-./.sandbox}/tui-build
#   needs: PERSONAS_DIR (bin/ensure-personas.sh provisions it). No external ST_ROOT / ST_HOOKS_DIR needed —
#          spin owns the isolated network and `convoy add` wires each agent's boot hooks itself.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/../../../bin/lib-harness.sh"
SB="${1:-${EVAL_SANDBOX:-./.sandbox}/tui-build}"
NET="$SB/st-root"                                   # SELF-ISOLATED convoy network (never the live one)
export ST_ROOT="$NET"                               # bus root; convoy places sessions under $NET/pty

[ -d "$SB/sup" ] || { echo "== sandbox absent — materializing =="; "$HERE/setup-sandbox.sh" "$SB"; }

# teardown: convoy down on CRASH/Ctrl-C/early-exit; LEAVE the team up on a clean spin (agents run async).
STEV_NET="$NET"
trap 'rc=$?; [ "$rc" = 0 ] || { echo "== spin rc=$rc — tearing down the isolated net ==" >&2; stev_convoy_teardown "$STEV_NET"; }' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

echo "== 1/5  convoy init the isolated network ($NET) =="
stev_convoy_init "$NET"

echo "== 2/5  compose personas (standalone files for --persona) =="
for r in sup tree cards ux; do "$HERE/compose-persona.sh" "$r" "$SB" >/dev/null && echo "   composed tui-$r"; done

echo "== 3/5  launch the workers first (convoy add: tree/cards/ux, auto) =="
for r in tree cards ux; do "$HERE/configure-claude-agent.sh" "$r" "$SB"; done

echo "== 4/5  launch the supervisor (convoy add: tui-sup, bypass) — creates its inbox + ding sidecar =="
"$HERE/configure-claude-agent.sh" sup "$SB"

echo "== 5/5  seed the hermetic build request into tui-sup's inbox; the ding sidecar delivers it (boot-time ms) =="
mkdir -p "$NET/tui-sup/inbox"
ms=$(( $(date +%s) * 1000 ))
sfx="$(printf '%06x' "$(( (RANDOM << 8 ^ RANDOM) & 0xffffff ))")"
sed -n '/^---$/,$p' "$HERE/kick-supervisor.md" > "$NET/tui-sup/inbox/${ms}-${sfx}.md"
echo "   seeded $NET/tui-sup/inbox/${ms}-${sfx}.md"

echo
echo "SPUN (tui-build cell, isolated convoy net at $NET). members:"
convoy ls "$NET" 2>/dev/null | grep -E 'tui-(sup|tree|cards|ux)' || convoy ls "$NET" 2>/dev/null || true
echo
echo "OBSERVE the message thread: tui-sup builds the shared data layer (src/data/network.ts -> st agents"
echo "  --enrich --json, read-only) -> briefs tui-tree + tui-cards to wire their views to it -> briefs"
echo "  tui-ux for the usability pass -> integrates -> drives the find->fix loop (ux finds, the view owner"
echo "  fixes, re-verify) -> reports to river. The built viz reads the FROZEN fixture (a SEPARATE root):"
echo "     ST_ROOT=$SB/fixture/smalltalk npm start   (and npm run cards)"
echo
echo "WAKE: agents wake via convoy's ding sidecar. To HOST + supervise + respawn on death: convoy up \"$NET\""
echo
echo "GRADE when the build closes:  fixture/grade.sh \"$SB\""
echo "TEARDOWN after grading:  convoy down \"$NET\"   (then rm -rf \"$SB\")"
