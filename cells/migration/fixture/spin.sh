#!/usr/bin/env bash
# Spin the Migration (dependency-bump) Claude cell via REAL convoy (ding-default, no MCP): mig-sup (bypass,
# coordinate-only) + mig-dev (auto, owns meeting-notes). Run AFTER setup-sandbox.sh (auto-materializes if the
# sandbox is absent). SELF-ISOLATING: `convoy init`s an isolated network at $SB/st-root so nothing touches
# the operator's live convoy — every session (agent + ding sidecar) lands under $NET/pty. Composes personas
# (standalone files for --persona), launches worker first + supervisor last, THEN seeds the hermetic
# migration-request kick into mig-sup's inbox — its `st ding` sidecar (created by convoy add) delivers it.
#
#   ./spin.sh [SANDBOX]        # sandbox defaults to ${EVAL_SANDBOX:-./.sandbox}/migration
#   needs: PERSONAS_DIR (bin/ensure-personas.sh provisions it). No external ST_ROOT / ST_HOOKS_DIR needed —
#          spin owns the isolated network and `convoy add` wires each agent's boot hooks itself.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/../../../bin/lib-harness.sh"
SB="${1:-${EVAL_SANDBOX:-./.sandbox}/migration}"
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
"$HERE/compose-persona.sh" dev "$SB"

echo "== 3/5  launch the worker first (convoy add: mig-dev, auto, owns meeting-notes) =="
# Pre-trust all agent dirs up front (before any spawn) so no earlier sibling's booted claude can stale-flush
# ~/.claude.json and clobber a later add's trust entry (workspace-trust stall). convoy pretrust = convoy's
# batch write, shared with convoy up; the harness no longer pre-trusts per-add (see lib-harness.sh). [convoy sweep: revalidate]
convoy pretrust "$SB/sup" "$SB/worker"

"$HERE/configure-claude-agent.sh" dev "$SB"

echo "== 4/5  launch the supervisor (convoy add: mig-sup, bypass) — creates its inbox + ding sidecar =="
"$HERE/configure-claude-agent.sh" sup "$SB"

echo "== 5/5  seed the hermetic kick into mig-sup's inbox; the ding sidecar delivers it (boot-time ms) =="
mkdir -p "$NET/mig-sup/inbox"
ms=$(( $(date +%s) * 1000 ))
sfx="$(printf '%06x' "$(( (RANDOM << 8 ^ RANDOM) & 0xffffff ))")"
sed -n '/^---$/,$p' "$HERE/kick-supervisor.md" > "$NET/mig-sup/inbox/${ms}-${sfx}.md"
echo "   seeded $NET/mig-sup/inbox/${ms}-${sfx}.md"

echo
echo "SPUN (Migration cell, isolated convoy net at $NET). members:"
convoy ls "$NET" 2>/dev/null | grep -E 'mig-sup|mig-dev' || convoy ls "$NET" 2>/dev/null
echo
echo "OBSERVE the message thread (ST_ROOT=$NET): kick -> mig-sup delegate -> mig-dev upgrade+fix-all-sites+"
echo "  preserve-batch+green -> report -> mig-sup read-only verify (greetkit 2.0.0? all call sites migrated?"
echo "  batch feature preserved+tested? tests not weakened? green?) -> confirm to eval-runner."
echo "WAKE: agents wake via convoy's ding sidecar. To HOST + supervise + respawn on death: convoy up \"$NET\""
echo
echo "TEARDOWN after grading:  convoy down \"$NET\"   (then rm -rf \"$SB\")"
