#!/usr/bin/env bash
# Spin the signal-rename cell via REAL convoy (ding-default, no MCP): sig-sup (bypass, integration lead, owns
# app.toml) + sig-base / sig-relay / sig-hub (auto, one product repo each). Run AFTER setup-sandbox.sh
# (auto-materializes if absent). SELF-ISOLATING: `convoy init`s an isolated COORDINATION network at
# $SB/st-root so nothing touches the operator's live convoy — every session (agent + ding sidecar) lands
# under $NET/pty. Launches the specialists FIRST + the supervisor LAST (so the sup boots to a seeded inbox),
# THEN seeds the hermetic rename request into sig-sup's inbox — its `st ding` sidecar (created by convoy add)
# delivers it.
#
#   ./spin.sh [SANDBOX]     # default: ${EVAL_SANDBOX:-./.sandbox}/signal-rename
#   needs: PERSONAS_DIR (bin/ensure-personas.sh provisions it). No external ST_ROOT / ST_HOOKS_DIR needed —
#          spin owns the isolated network and `convoy add` wires each agent's boot hooks itself.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/../../../bin/lib-harness.sh"
SB="${1:-${EVAL_SANDBOX:-./.sandbox}/signal-rename}"
NET="$SB/st-root"                                   # SELF-ISOLATED convoy network (never the live one)
export ST_ROOT="$NET"                               # bus root; convoy places sessions under $NET/pty

[ -d "$SB/base" ] || { echo "== sandbox absent — materializing =="; "$HERE/setup-sandbox.sh" "$SB"; }

# teardown: convoy down on CRASH/Ctrl-C/early-exit; LEAVE the team up on a clean spin (agents run async).
STEV_NET="$NET"
trap 'rc=$?; [ "$rc" = 0 ] || { echo "== spin rc=$rc — tearing down the isolated net ==" >&2; stev_convoy_teardown "$STEV_NET"; }' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

echo "== 1/5  convoy init the isolated network ($NET) =="
stev_convoy_init "$NET"

echo "== 2/5  compose personas (standalone files for --persona) =="
for r in sup base relay hub; do "$HERE/compose-persona.sh" "$r" "$SB" >/dev/null && echo "   composed sig-$r"; done

echo "== 3/5  launch the specialists first (convoy add: base/relay/hub, auto) =="
# Pre-trust all agent dirs up front (before any spawn) so no earlier sibling's booted claude can stale-flush
# ~/.claude.json and clobber a later add's trust entry (workspace-trust stall). convoy pretrust = convoy's
# batch write, shared with convoy up; the harness no longer pre-trusts per-add (see lib-harness.sh). [convoy sweep: revalidate]
convoy pretrust "$SB/base" "$SB/hub" "$SB/relay" "$SB/sup"

for r in base relay hub; do "$HERE/configure-claude-agent.sh" "$r" "$SB"; done

echo "== 4/5  launch the supervisor (convoy add: sig-sup, bypass) — creates its inbox + ding sidecar =="
"$HERE/configure-claude-agent.sh" sup "$SB"

echo "== 5/5  seed the hermetic rename request into sig-sup's inbox; the ding sidecar delivers it (boot-time ms) =="
mkdir -p "$NET/sig-sup/inbox"
ms=$(( $(date +%s) * 1000 ))
sfx="$(printf '%06x' "$(( (RANDOM << 8 ^ RANDOM) & 0xffffff ))")"
sed -n '/^---$/,$p' "$HERE/kick-supervisor.md" > "$NET/sig-sup/inbox/${ms}-${sfx}.md"
echo "   seeded $NET/sig-sup/inbox/${ms}-${sfx}.md"

echo
echo "SPUN (signal-rename cell, isolated convoy net at $NET). members:"
convoy ls "$NET" 2>/dev/null | grep -E 'sig-(sup|base|relay|hub)' || convoy ls "$NET" 2>/dev/null || true
echo
echo "OBSERVE the message thread: sig-sup sequences the cutover — briefs sig-base to rename @acme/signal->@acme/beacon"
echo "  (+ the bin) FIRST with a compat/alias window; sig-base signals the consumers; then sig-relay + sig-hub bump"
echo "  peerDep + imports (+ signal://->beacon:// for the hub), each keeping node --test GREEN and the PRIMITIVE"
echo "  (AbortSignal/SIGTERM) intact; sig-sup renames app.toml + integrates + reports to the requester (morgan)."
echo
echo "GRADE when the rename closes:  fixture/grade.sh \"$SB\""
echo "TEARDOWN after grading:  convoy down \"$NET\"   (then rm -rf \"$SB\")"
