#!/usr/bin/env bash
# Spin the Test-writing Claude cell: tw-sup (bypass, coordinate-only) + tw-dev (auto, owns grades).
# Run AFTER setup-sandbox.sh. Composes personas, wires coord+asyncRewake+pre-trust, seeds the hermetic
# request into tw-sup's inbox, and launches (worker first, sup last). After the team reports, grade with
# grade.sh (isolation + lane + green-on-original + tests-added + MUTATION SCORE across the mutant battery).
#
#   ./spin.sh            # sandbox defaults to ${EVAL_SANDBOX:-./.sandbox}/test-writing
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SB="${1:-${EVAL_SANDBOX:-./.sandbox}/test-writing}"
ROOT="${ST_ROOT:-${XDG_STATE_HOME:-$HOME/.local/state}/smalltalk}"

echo "== 1/4  compose personas (CLAUDE.md) =="
"$HERE/compose-persona.sh" sup "$SB"
"$HERE/compose-persona.sh" dev "$SB"

echo "== 2/4  wire agents (sup=bypass, dev=auto) =="
"$HERE/configure-claude-agent.sh" sup "$SB"
"$HERE/configure-claude-agent.sh" dev "$SB"

echo "== 3/4  seed the hermetic request into tw-sup's inbox (boot-time ms; strip HTML header) =="
ms=$(( $(date +%s) * 1000 ))
sfx="$(printf '%06x' "$(( (RANDOM << 8 ^ RANDOM) & 0xffffff ))")"
sed -n '/^---$/,$p' "$HERE/kick-supervisor.md" > "$ROOT/tw-sup/inbox/${ms}-${sfx}.md"
echo "   seeded $ROOT/tw-sup/inbox/${ms}-${sfx}.md"

echo "== 4/4  launch (pty up) — worker first, supervisor last =="
for pair in "dev:$SB/worker" "sup:$SB/sup"; do
  d="${pair#*:}"; echo "   pty up in $d"; ( cd "$d" && pty up )
done

echo
echo "SPUN (Test-writing cell). sessions:"; pty ls 2>/dev/null | grep -E "tw-(sup|dev)-" || pty ls
echo
echo "OBSERVE: request -> tw-sup delegate -> tw-dev read module -> write a THOROUGH suite (boundaries+edges+errors, exact asserts) -> commit -> report"
echo "  -> tw-sup read-only verify (green? src unchanged? would it CATCH a regression, or shallow?) -> confirm to eval-runner."
echo "THEN grade: fixtures/test-writing/grade.sh (MUTATION SCORE across 12 mutants; validated: strong=12/12 PASS, shallow=2/12 FAIL)"
echo "WAKE backstop: bin/shepherd-poke.sh \"tw-sup tw-dev\" 40 180 &"
