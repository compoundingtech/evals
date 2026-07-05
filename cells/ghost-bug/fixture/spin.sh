#!/usr/bin/env bash
# Spin the Ghost-bug (debug) Claude cell: gb-sup (bypass, coordinate-only) + gb-fix (auto, owns
# labelkit). Run AFTER setup-sandbox.sh. Composes personas, wires coord+asyncRewake, seeds the
# hermetic bug-report kick into gb-sup's inbox, and launches (worker first, supervisor last).
# Claude agents auto-wake via the asyncRewake hook but still need shepherd-poke.sh as an HB-4 backstop.
#
#   ./spin.sh            # sandbox defaults to ${EVAL_SANDBOX:-./.sandbox}/ghost-bug
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SB="${1:-${EVAL_SANDBOX:-./.sandbox}/ghost-bug}"
ROOT="${ST_ROOT:-${XDG_STATE_HOME:-$HOME/.local/state}/smalltalk}"

echo "== 1/4  compose personas (CLAUDE.md) =="
"$HERE/compose-persona.sh" sup "$SB"
"$HERE/compose-persona.sh" fix "$SB"

echo "== 2/4  wire agents (sup=bypass, fix=auto) =="
"$HERE/configure-claude-agent.sh" sup "$SB"
"$HERE/configure-claude-agent.sh" fix "$SB"

echo "== 3/4  seed the hermetic kick into gb-sup's inbox (boot-time ms; strip HTML header) =="
ms=$(( $(date +%s) * 1000 ))
sfx="$(printf '%06x' "$(( (RANDOM << 8 ^ RANDOM) & 0xffffff ))")"
sed -n '/^---$/,$p' "$HERE/kick-supervisor.md" > "$ROOT/gb-sup/inbox/${ms}-${sfx}.md"
echo "   seeded $ROOT/gb-sup/inbox/${ms}-${sfx}.md"

echo "== 4/4  launch (pty up) — worker first, supervisor last =="
for pair in "fix:$SB/worker" "sup:$SB/sup"; do
  d="${pair#*:}"; echo "   pty up in $d"; ( cd "$d" && pty up )
done

echo
echo "SPUN (Ghost-bug cell). sessions:"; pty ls 2>/dev/null | grep -E "gb-(sup|fix)-" || pty ls
echo
echo "OBSERVE the coord thread: kick -> gb-sup delegate -> gb-fix reproduce+root-cause+fix+regression-test+report"
echo "  -> gb-sup read-only verify (root-cause not band-aid? regression test would-fail-on-old? suite green?) -> confirm to eval-runner."
echo "WAKE: Claude auto-wakes via asyncRewake, but run the HB-4 backstop if agents idle on delivered msgs:"
echo "  bin/shepherd-poke.sh \"gb-sup gb-fix\" 40 180 &"
