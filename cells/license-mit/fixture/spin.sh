#!/usr/bin/env bash
# Spin the license-mit (team-loop smoke) Claude cell via REAL convoy (ding-default, no MCP): mix-sup (bypass,
# coordinate-only) + mix-worker (auto, owns the widget repo). The smallest end-to-end proof of the
# system: one instruction in ("license should be MIT"), a coordinated delegate->execute->verify->confirm
# loop out, isolation held. This is the Claude-only default (matches the cell's declared caps + is the
# most reliable from-scratch/clean-box run); codex/glm are optional matrix variants (configure-*-agent.sh).
# SELF-ISOLATING: `convoy init`s an isolated network at $SB/st-root so nothing touches the operator's live
# convoy — every session (agent + ding sidecar) lands under $NET/pty.
#
#   ./spin.sh [SANDBOX]        # sandbox defaults to ${EVAL_SANDBOX:-./.sandbox}/license-mixed
#   needs: PERSONAS_DIR (bin/ensure-personas.sh provisions it). No external ST_ROOT / ST_HOOKS_DIR needed —
#          spin owns the isolated network and `convoy add` wires each agent's boot hooks itself.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/../../../bin/lib-harness.sh"
SB="${1:-${EVAL_SANDBOX:-./.sandbox}/license-mixed}"
NET="$SB/st-root"                                   # SELF-ISOLATED convoy network (never the live one)
export ST_ROOT="$NET"                               # bus root; convoy places sessions under $NET/pty
SUP_ID="${SUP_ID:-mix-sup}"; WORKER_ID="${WORKER_ID:-mix-worker}"
REQUESTER="${REQUESTER:-eval-runner}"              # who sends the kick + whom the sup confirms back to
# configure-claude-agent.sh runs as a separate process and reads these under `set -u` — must be EXPORTED.
export SUP_ID WORKER_ID REQUESTER

[ -d "$SB/worker" ] || { echo "== sandbox absent — materializing =="; "$HERE/setup-sandbox.sh" "$SB"; }

# teardown: convoy down on CRASH/Ctrl-C/early-exit; LEAVE the team up on a clean spin (agents run async).
STEV_NET="$NET"
trap 'rc=$?; [ "$rc" = 0 ] || { echo "== spin rc=$rc — tearing down the isolated net ==" >&2; stev_convoy_teardown "$STEV_NET"; }' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

echo "== 1/5  convoy init the isolated network ($NET) =="
stev_convoy_init "$NET"

echo "== 2/5  compose personas (standalone files for --persona) =="
"$HERE/compose-persona.sh" sup    claude "$SB"
"$HERE/compose-persona.sh" worker claude "$SB"

echo "== 3/5  launch the worker first (convoy add: $WORKER_ID, auto, owns widget) =="
# Pre-trust all agent dirs up front (before any spawn) so no earlier sibling's booted claude can stale-flush
# ~/.claude.json and clobber a later add's trust entry (workspace-trust stall). convoy pretrust = convoy's
# batch write, shared with convoy up; the harness no longer pre-trusts per-add (see lib-harness.sh). [convoy sweep: revalidate]
convoy pretrust "$SB/sup" "$SB/worker"

"$HERE/configure-claude-agent.sh" worker "$SB"

echo "== 4/5  launch the supervisor (convoy add: $SUP_ID, bypass) — creates its inbox + ding sidecar =="
"$HERE/configure-claude-agent.sh" sup "$SB"

echo "== 5/5  seed the hermetic kick — deliver it to $SUP_ID over the REAL isolated bus =="
# convoy runs smalltalk under $NET/smalltalk and host-prefixes agents (hetz.$SUP_ID); the pre-convoy
# '$NET/$SUP_ID/inbox' file-drop landed where nobody watched → hollow green. stev_seed_kick (lib-harness)
# waits for the sup to register, resolves the host-prefixed id, and st-sends the kick (which also pokes the
# sup's ding socket). Shared by every team-loop cell so the fix lives in ONE place.
stev_seed_kick "$NET" "$SUP_ID" "$HERE/kick-supervisor.md" "$REQUESTER"

echo
echo "SPUN (license-mit cell, isolated convoy net at $NET). members:"
convoy ls "$NET" 2>/dev/null | grep -E "$SUP_ID|$WORKER_ID" || convoy ls "$NET" 2>/dev/null
echo
echo "OBSERVE the loop (ST_ROOT=$NET): kick -> $SUP_ID delegates by message -> $WORKER_ID replaces LICENSE"
echo "  with canonical MIT + commits -> $SUP_ID read-only verify (MIT? committed? tree clean? lane held?)"
echo "  -> confirm to eval-runner. Isolation gate: only $WORKER_ID may commit to the widget repo."
echo "WAKE: agents wake via convoy's ding sidecar. To HOST + supervise + respawn on death: convoy up \"$NET\""
echo
echo "TEARDOWN after grading:  convoy down \"$NET\"   (then rm -rf \"$SB\")"
