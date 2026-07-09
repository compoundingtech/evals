#!/usr/bin/env bash
# Spin the license-mit CODEX cell via REAL convoy (`--harness codex`, ding-default, no MCP): lmc-sup
# (bypass, coordinate-only) + lmc-worker (auto, owns the widget repo). Run AFTER setup-sandbox.sh (auto-
# materializes if absent). SELF-ISOLATING: `convoy init`s an isolated network at $SB/st-root so nothing
# touches the live convoy — every session (codex agent + its `st ding` sidecar) lands under $NET/pty.
# Composes personas (standalone files for --persona), launches worker first + supervisor last, THEN seeds
# the MIT-license kick into lmc-sup's inbox — its ding sidecar delivers it. Codex has no auto-boot-ritual.
#
#   ./spin.sh [SANDBOX]        # sandbox defaults to ${EVAL_SANDBOX:-./.sandbox}/license-mit-codex
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/../../../bin/lib-harness.sh"
SB="${1:-${EVAL_SANDBOX:-./.sandbox}/license-mit-codex}"
NET="$SB/st-root"; export ST_ROOT="$NET"            # SELF-ISOLATED convoy network (never the live one)

[ -d "$SB/worker" ] || { echo "== sandbox absent — materializing =="; "$HERE/setup-sandbox.sh" "$SB"; }

STEV_NET="$NET"
trap 'rc=$?; [ "$rc" = 0 ] || { echo "== spin rc=$rc — tearing down the isolated net ==" >&2; stev_convoy_teardown "$STEV_NET"; }' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

echo "== 1/5  convoy init the isolated network ($NET) =="
stev_convoy_init "$NET"
echo "== 2/5  compose personas (standalone files for --persona) =="
"$HERE/compose-persona.sh" sup    "$SB"
"$HERE/compose-persona.sh" worker "$SB"
echo "== 3/5  launch the worker first (convoy add --harness codex: lmc-worker, auto, owns the widget repo) =="
"$HERE/configure-codex-agent.sh" worker "$SB"
echo "== 4/5  launch the supervisor (convoy add --harness codex: lmc-sup, bypass) — creates its inbox + ding sidecar =="
"$HERE/configure-codex-agent.sh" sup "$SB"
echo "== 5/5  seed the MIT-license kick into lmc-sup's inbox; the ding sidecar delivers it =="
mkdir -p "$NET/lmc-sup/inbox"
ms=$(( $(date +%s) * 1000 )); sfx="$(printf '%06x' "$(( (RANDOM << 8 ^ RANDOM) & 0xffffff ))")"
sed -n '/^---$/,$p' "$HERE/kick-supervisor.md" > "$NET/lmc-sup/inbox/${ms}-${sfx}.md"
echo "   seeded $NET/lmc-sup/inbox/${ms}-${sfx}.md"

echo
echo "SPUN (Codex license-mit cell, isolated convoy net at $NET). members:"
convoy ls "$NET" 2>/dev/null | grep -E 'lmc-sup|lmc-worker' || convoy ls "$NET" 2>/dev/null
echo "OBSERVE (ST_ROOT=$NET): kick -> lmc-sup delegate -> lmc-worker changes LICENSE->MIT + commits -> reports ->"
echo "  lmc-sup verifies read-only -> confirms. HARD GATE: only lmc-worker commits to the widget repo."
echo "WAKE: Codex wakes via convoy's st ding sidecar; nudge lmc-sup to boot (wake tax)."
echo "TEARDOWN after grading:  convoy down \"$NET\"   (then rm -rf \"$SB\")"
