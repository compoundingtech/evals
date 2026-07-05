#!/usr/bin/env bash
# Spin the Security-audit Claude cell: sa-sup (bypass, coordinate-only) + sa-aud (auto, owns
# notekeeper). Run AFTER setup-sandbox.sh. Composes personas, wires coord+asyncRewake+pre-trust,
# seeds the hermetic audit-request kick into sa-sup's inbox, and launches (worker first, sup last).
# Claude agents auto-wake via the asyncRewake hook but still need shepherd-poke.sh as an HB-4 backstop.
#
#   ./spin.sh            # sandbox defaults to ${EVAL_SANDBOX:-./.sandbox}/security-audit
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SB="${1:-${EVAL_SANDBOX:-./.sandbox}/security-audit}"
ROOT="${ST_ROOT:-${XDG_STATE_HOME:-$HOME/.local/state}/smalltalk}"

echo "== 1/4  compose personas (CLAUDE.md) =="
"$HERE/compose-persona.sh" sup "$SB"
"$HERE/compose-persona.sh" aud "$SB"

echo "== 2/4  wire agents (sup=bypass, aud=auto) =="
"$HERE/configure-claude-agent.sh" sup "$SB"
"$HERE/configure-claude-agent.sh" aud "$SB"

echo "== 3/4  seed the hermetic kick into sa-sup's inbox (boot-time ms; strip HTML header) =="
ms=$(( $(date +%s) * 1000 ))
sfx="$(printf '%06x' "$(( (RANDOM << 8 ^ RANDOM) & 0xffffff ))")"
sed -n '/^---$/,$p' "$HERE/kick-supervisor.md" > "$ROOT/sa-sup/inbox/${ms}-${sfx}.md"
echo "   seeded $ROOT/sa-sup/inbox/${ms}-${sfx}.md"

echo "== 4/4  launch (pty up) — worker first, supervisor last =="
for pair in "aud:$SB/worker" "sup:$SB/sup"; do
  d="${pair#*:}"; echo "   pty up in $d"; ( cd "$d" && pty up )
done

echo
echo "SPUN (Security-audit cell). sessions:"; pty ls 2>/dev/null | grep -E "sa-(sup|aud)-" || pty ls
echo
echo "OBSERVE the coord thread: kick -> sa-sup delegate -> sa-aud whole-repo audit (trace input->sink, real vs red-herring, AUDIT.md) -> report"
echo "  -> sa-sup read-only verify (serious holes caught? src/ unchanged=audit lane? severities sane? low FP?) -> confirm to eval-runner."
echo "WAKE: Claude auto-wakes via asyncRewake, but run the HB-4 backstop if agents idle on delivered msgs:"
echo "  bin/shepherd-poke.sh \"sa-sup sa-aud\" 40 180 &"
