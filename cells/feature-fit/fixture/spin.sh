#!/usr/bin/env bash
# Spin the Feature-fit Claude cell: feat-sup (bypass, coordinate-only) + feat-dev (auto, owns tasklit).
# Run AFTER setup-sandbox.sh. Composes personas, wires coord+asyncRewake+pre-trust, seeds the hermetic
# feature request into feat-sup's inbox, and launches (worker first, sup last). After the team reports,
# grade with grade.sh (isolation + suite + FUNCTIONAL via dispatch + test-added + convention-fit).
#
#   ./spin.sh            # sandbox defaults to ${EVAL_SANDBOX:-./.sandbox}/feature-fit
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SB="${1:-${EVAL_SANDBOX:-./.sandbox}/feature-fit}"
ROOT="${ST_ROOT:-${XDG_STATE_HOME:-$HOME/.local/state}/smalltalk}"

echo "== 1/4  compose personas (CLAUDE.md) =="
"$HERE/compose-persona.sh" sup "$SB"
"$HERE/compose-persona.sh" dev "$SB"

echo "== 2/4  wire agents (sup=bypass, dev=auto) =="
"$HERE/configure-claude-agent.sh" sup "$SB"
"$HERE/configure-claude-agent.sh" dev "$SB"

echo "== 3/4  seed the hermetic feature request into feat-sup's inbox (boot-time ms; strip HTML header) =="
ms=$(( $(date +%s) * 1000 ))
sfx="$(printf '%06x' "$(( (RANDOM << 8 ^ RANDOM) & 0xffffff ))")"
sed -n '/^---$/,$p' "$HERE/kick-supervisor.md" > "$ROOT/feat-sup/inbox/${ms}-${sfx}.md"
echo "   seeded $ROOT/feat-sup/inbox/${ms}-${sfx}.md"

echo "== 4/4  launch (pty up) — worker first, supervisor last =="
for pair in "dev:$SB/worker" "sup:$SB/sup"; do
  d="${pair#*:}"; echo "   pty up in $d"; ( cd "$d" && pty up )
done

echo
echo "SPUN (Feature-fit cell). sessions:"; pty ls 2>/dev/null | grep -E "feat-(sup|dev)-" || pty ls
echo
echo "OBSERVE: request -> feat-sup delegate -> feat-dev READ existing commands -> add rename matching the conventions -> commit -> report"
echo "  -> feat-sup read-only verify (works? suite green? FITS the house style — result pattern, shared validators, registered, matching test?) -> confirm to eval-runner."
echo "THEN grade: fixtures/feature-fit/grade.sh (validated on good/alien/throws mocks: idiomatic=10/0/0, alien=8/0/2W, throws=6/3F)"
echo "WAKE backstop: bin/shepherd-poke.sh \"feat-sup feat-dev\" 40 180 &"
