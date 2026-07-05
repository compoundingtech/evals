#!/usr/bin/env bash
# Spin the Incident-response Claude cell: ir-sup (bypass, coordinate-only) + ir-oncall (auto, owns
# pulse). Run AFTER setup-sandbox.sh. Composes personas, wires coord+asyncRewake+pre-trust, seeds the
# hermetic incident page into ir-sup's inbox, and launches (worker first, sup last).
# Claude agents auto-wake via asyncRewake but still need shepherd-poke.sh as an HB-4 backstop.
#
#   ./spin.sh            # sandbox defaults to ${EVAL_SANDBOX:-./.sandbox}/incident-response
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SB="${1:-${EVAL_SANDBOX:-./.sandbox}/incident-response}"
ROOT="${ST_ROOT:-${XDG_STATE_HOME:-$HOME/.local/state}/smalltalk}"

echo "== 1/4  compose personas (CLAUDE.md) =="
"$HERE/compose-persona.sh" sup "$SB"
"$HERE/compose-persona.sh" oncall "$SB"

echo "== 2/4  wire agents (sup=bypass, oncall=auto) =="
"$HERE/configure-claude-agent.sh" sup "$SB"
"$HERE/configure-claude-agent.sh" oncall "$SB"

echo "== 3/4  seed the hermetic incident page into ir-sup's inbox (boot-time ms; strip HTML header) =="
ms=$(( $(date +%s) * 1000 ))
sfx="$(printf '%06x' "$(( (RANDOM << 8 ^ RANDOM) & 0xffffff ))")"
sed -n '/^---$/,$p' "$HERE/kick-supervisor.md" > "$ROOT/ir-sup/inbox/${ms}-${sfx}.md"
echo "   seeded $ROOT/ir-sup/inbox/${ms}-${sfx}.md"

echo "== 4/4  launch (pty up) — worker first, supervisor last =="
for pair in "oncall:$SB/worker" "sup:$SB/sup"; do
  d="${pair#*:}"; echo "   pty up in $d"; ( cd "$d" && pty up )
done

echo
echo "SPUN (Incident-response cell). sessions:"; pty ls 2>/dev/null | grep -E "ir-(sup|oncall)-" || pty ls
echo
echo "OBSERVE the coord thread: page -> ir-sup triage+delegate -> ir-oncall reproduce -> mitigate -> ROOT fix + regression test -> report"
echo "  -> ir-sup read-only verify (500 gone AND values correct? root cause fixed not masked? regression test real? suite green? lane held?) -> confirm to eval-runner."
echo "WAKE: Claude auto-wakes via asyncRewake, but run the HB-4 backstop if agents idle on delivered msgs:"
echo "  bin/shepherd-poke.sh \"ir-sup ir-oncall\" 40 180 &"
