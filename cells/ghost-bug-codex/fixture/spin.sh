#!/usr/bin/env bash
# Spin the Ghost-bug CODEX cell via REAL convoy (`--harness codex`, ding-default, no MCP): gbx-sup (bypass,
# coordinate-only) + gbx-fix (auto, owns labelkit). Run AFTER setup-sandbox.sh (auto-materializes if the
# sandbox is absent). SELF-ISOLATING: `convoy init`s an isolated network at $SB/st-root so nothing touches
# the operator's live convoy — every session (codex agent + its `st ding` wake sidecar) lands under
# $NET/pty. Composes personas (standalone files for --persona), launches worker first + supervisor last,
# THEN seeds the hermetic bug-report kick into gbx-sup's inbox — its `st ding` sidecar (created by convoy
# add --harness codex) delivers it. Codex has no auto-boot-ritual, so expect to nudge gbx-sup to start and
# the worker on each delegation round (the Codex wake tax).
#
#   ./spin.sh [SANDBOX]        # sandbox defaults to ${EVAL_SANDBOX:-./.sandbox}/ghost-bug-codex
#   needs: PERSONAS_DIR (bin/ensure-personas.sh provisions it). No external ST_ROOT/ST_HOOKS_DIR needed —
#          spin owns the isolated network and `convoy add` wires each agent's codex rig itself.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/../../../bin/lib-harness.sh"
SB="${1:-${EVAL_SANDBOX:-./.sandbox}/ghost-bug-codex}"
NET="$SB/st-root"                                   # SELF-ISOLATED convoy network (never the live one)
export ST_ROOT="$NET"                               # bus root; convoy places sessions under $NET/pty

[ -d "$SB/worker" ] || { echo "== sandbox absent — materializing =="; "$HERE/setup-sandbox.sh" "$SB"; }

# teardown: convoy down on CRASH/Ctrl-C/early-exit; LEAVE the team up on a clean spin (agents run async).
STEV_NET="$NET"
trap 'rc=$?; [ "$rc" = 0 ] || { echo "== spin rc=$rc — tearing down the isolated net ==" >&2; stev_convoy_teardown "$STEV_NET"; }' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

echo "== 1/5  convoy init the isolated network ($NET) =="
stev_convoy_init "$NET"

echo "== 2/5  compose personas (standalone files for --persona) =="
"$HERE/compose-persona.sh" sup "$SB"
"$HERE/compose-persona.sh" fix "$SB"

echo "== 3/5  launch the worker first (convoy add --harness codex: gbx-fix, auto, owns labelkit) =="
"$HERE/configure-codex-agent.sh" fix "$SB"

echo "== 4/5  launch the supervisor (convoy add --harness codex: gbx-sup, bypass) — creates its inbox + ding sidecar =="
"$HERE/configure-codex-agent.sh" sup "$SB"

echo "== 5/5  seed the hermetic kick into gbx-sup's inbox; the ding sidecar delivers it (boot-time ms) =="
mkdir -p "$NET/gbx-sup/inbox"
ms=$(( $(date +%s) * 1000 ))
sfx="$(printf '%06x' "$(( (RANDOM << 8 ^ RANDOM) & 0xffffff ))")"
sed -n '/^---$/,$p' "$HERE/kick-supervisor.md" > "$NET/gbx-sup/inbox/${ms}-${sfx}.md"
echo "   seeded $NET/gbx-sup/inbox/${ms}-${sfx}.md"

echo
echo "SPUN (Codex Ghost-bug cell, isolated convoy net at $NET). members:"
convoy ls "$NET" 2>/dev/null | grep -E 'gbx-sup|gbx-fix' || convoy ls "$NET" 2>/dev/null
echo
echo "OBSERVE the thread (ST_ROOT=$NET): kick -> gbx-sup delegate -> gbx-fix reproduce+root-cause+fix+"
echo "  regression-test+report -> gbx-sup read-only verify (root-cause not band-aid? regression test would-fail-"
echo "  on-old? suite green?) -> confirm to eval-runner."
echo "WAKE: Codex wakes via convoy's st ding sidecar (no asyncRewake). Nudge gbx-sup to boot + the worker on"
echo "  each delegation round (the Codex wake tax). To HOST + supervise + respawn on death: convoy up \"$NET\""
echo
echo "TEARDOWN after grading:  convoy down \"$NET\"   (then rm -rf \"$SB\")"
