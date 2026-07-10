#!/usr/bin/env bash
# Spin the DING-MODE (no-MCP participation) Claude cell via REAL convoy (`convoy add`, ding-default): BOTH
# agents join WITHOUT MCP — dm-sup (bypass, coordinate-only) + dm-dev (auto, owns widget), each with an
# `st ding` sidecar + the `st` CLI for all bus ops. Run AFTER setup-sandbox.sh (auto-materializes).
# SELF-ISOLATING: `convoy init`s an isolated network at $SB/st-root; convoy add lands every session under $NET/pty.
#   ./spin.sh [SANDBOX]        # sandbox defaults to ${EVAL_SANDBOX:-./.sandbox}/ding-mode
#   needs: PERSONAS_DIR (bin/ensure-personas.sh provisions it).
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/../../../bin/lib-harness.sh"
SB="${1:-${EVAL_SANDBOX:-./.sandbox}/ding-mode}"
NET="$SB/st-root"; export ST_ROOT="$NET"            # SELF-ISOLATED convoy network (never the live one)

[ -d "$SB/widget" ] || { echo "== sandbox absent — materializing =="; "$HERE/setup-sandbox.sh" "$SB"; }

STEV_NET="$NET"
trap 'rc=$?; [ "$rc" = 0 ] || { echo "== spin rc=$rc — tearing down the isolated net ==" >&2; stev_convoy_teardown "$STEV_NET"; }' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

echo "== 1/4  convoy init the isolated network ($NET) =="
stev_convoy_init "$NET"
echo "== 2/4  compose ding-mode personas (convoy add installs the bus contract as DING-BUS.md) =="
"$HERE/compose-persona.sh" sup "$SB"
"$HERE/compose-persona.sh" dev "$SB"
echo "== 3/4  launch the worker first (convoy add: dm-dev, auto, owns widget), then the supervisor (dm-sup, bypass) =="
"$HERE/configure-claude-agent.sh" dev "$SB"
"$HERE/configure-claude-agent.sh" sup "$SB"
echo "== 4/4  seed the hermetic kick into dm-sup's inbox; its ding sidecar delivers it =="
mkdir -p "$NET/dm-sup/inbox"
ms=$(( $(date +%s) * 1000 )); sfx="$(printf '%06x' "$(( (RANDOM << 8 ^ RANDOM) & 0xffffff ))")"
sed -n '/^---$/,$p' "$HERE/kick-supervisor.md" > "$NET/dm-sup/inbox/${ms}-${sfx}.md"
echo "   seeded $NET/dm-sup/inbox/${ms}-${sfx}.md"

echo
echo "SPUN (Ding-mode cell, isolated convoy net $NET). members:"; convoy ls "$NET" 2>/dev/null | grep -E 'dm-sup|dm-dev' || convoy ls "$NET" 2>/dev/null
echo "OBSERVE (ST_ROOT=$NET) — a fully NO-MCP loop: dm-sup boot-drains the kick via the st CLI -> delegates to"
echo "  dm-dev over the bus -> dm-dev gets a [DING], reads via CLI, implements slugify + commits + reports ->"
echo "  dm-sup verifies read-only -> confirms to eval-runner. Inbound = [DING] pokes; all ops = st CLI."
echo "GRADE after the loop settles:  $HERE/grade.sh \"$SB\""
echo "TEARDOWN after grading:        convoy down \"$NET\"   (then rm -rf \"$SB\")"
