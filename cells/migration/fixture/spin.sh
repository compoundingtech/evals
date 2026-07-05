#!/usr/bin/env bash
# Spin the Migration (dependency-bump) Claude cell: mig-sup (bypass, coordinate-only) + mig-dev
# (auto, owns meeting-notes). Run AFTER setup-sandbox.sh. Composes personas, wires coord+asyncRewake,
# seeds the hermetic migration-request kick into mig-sup's inbox, and launches (worker first, sup last).
# Claude agents auto-wake via the asyncRewake hook but still need shepherd-poke.sh as an HB-4 backstop.
#
#   ./spin.sh            # sandbox defaults to ${EVAL_SANDBOX:-./.sandbox}/migration
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SB="${1:-${EVAL_SANDBOX:-./.sandbox}/migration}"
ROOT="${ST_ROOT:-${XDG_STATE_HOME:-$HOME/.local/state}/smalltalk}"

echo "== 1/4  compose personas (CLAUDE.md) =="
"$HERE/compose-persona.sh" sup "$SB"
"$HERE/compose-persona.sh" dev "$SB"

echo "== 2/4  wire agents (sup=bypass, dev=auto) =="
"$HERE/configure-claude-agent.sh" sup "$SB"
"$HERE/configure-claude-agent.sh" dev "$SB"

echo "== 3/4  seed the hermetic kick into mig-sup's inbox (boot-time ms; strip HTML header) =="
ms=$(( $(date +%s) * 1000 ))
sfx="$(printf '%06x' "$(( (RANDOM << 8 ^ RANDOM) & 0xffffff ))")"
sed -n '/^---$/,$p' "$HERE/kick-supervisor.md" > "$ROOT/mig-sup/inbox/${ms}-${sfx}.md"
echo "   seeded $ROOT/mig-sup/inbox/${ms}-${sfx}.md"

echo "== 4/4  launch (pty up) — worker first, supervisor last =="
for pair in "dev:$SB/worker" "sup:$SB/sup"; do
  d="${pair#*:}"; echo "   pty up in $d"; ( cd "$d" && pty up )
done

echo
echo "SPUN (Migration cell). sessions:"; pty ls 2>/dev/null | grep -E "mig-(sup|dev)-" || pty ls
echo
echo "OBSERVE the coord thread: kick -> mig-sup delegate -> mig-dev upgrade+fix-all-sites+preserve-batch+green -> report"
echo "  -> mig-sup read-only verify (greetkit 2.0.0? all call sites migrated? batch feature preserved+tested? tests not weakened? green?) -> confirm to eval-runner."
echo "WAKE: Claude auto-wakes via asyncRewake, but run the HB-4 backstop if agents idle on delivered msgs:"
echo "  bin/shepherd-poke.sh \"mig-sup mig-dev\" 40 180 &"
