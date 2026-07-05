#!/usr/bin/env bash
# Spin the Docs Claude cell: doc-sup (bypass, coordinate-only) + doc-writer (auto, owns checkout).
# Run AFTER setup-sandbox.sh. Composes personas, wires coord+asyncRewake+pre-trust, seeds the hermetic
# docs request into doc-sup's inbox, and launches (worker first, sup last). After the team reports,
# grade the docs held-out with cold-reader.sh (a fresh docs-only agent) + grade.sh.
#
#   ./spin.sh            # sandbox defaults to ${EVAL_SANDBOX:-./.sandbox}/docs
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SB="${1:-${EVAL_SANDBOX:-./.sandbox}/docs}"
ROOT="${ST_ROOT:-${XDG_STATE_HOME:-$HOME/.local/state}/smalltalk}"

echo "== 1/4  compose personas (CLAUDE.md) =="
"$HERE/compose-persona.sh" sup "$SB"
"$HERE/compose-persona.sh" writer "$SB"

echo "== 2/4  wire agents (sup=bypass, writer=auto) =="
"$HERE/configure-claude-agent.sh" sup "$SB"
"$HERE/configure-claude-agent.sh" writer "$SB"

echo "== 3/4  seed the hermetic docs request into doc-sup's inbox (boot-time ms; strip HTML header) =="
ms=$(( $(date +%s) * 1000 ))
sfx="$(printf '%06x' "$(( (RANDOM << 8 ^ RANDOM) & 0xffffff ))")"
sed -n '/^---$/,$p' "$HERE/kick-supervisor.md" > "$ROOT/doc-sup/inbox/${ms}-${sfx}.md"
echo "   seeded $ROOT/doc-sup/inbox/${ms}-${sfx}.md"

echo "== 4/4  launch (pty up) — worker first, supervisor last =="
for pair in "writer:$SB/worker" "sup:$SB/sup"; do
  d="${pair#*:}"; echo "   pty up in $d"; ( cd "$d" && pty up )
done

echo
echo "SPUN (Docs cell). sessions:"; pty ls 2>/dev/null | grep -E "doc-(sup|writer)-" || pty ls
echo
echo "OBSERVE: request -> doc-sup delegate -> doc-writer read code+tests -> write README/docs (surface the 3 gotchas) -> commit -> report"
echo "  -> doc-sup read-only verify (accurate? complete? cold-usable? src unchanged? suite green?) -> confirm to eval-runner."
echo "THEN grade held-out: fixtures/docs/cold-reader.sh (fresh docs-only agent computes a total) + fixtures/docs/grade.sh"
echo "WAKE backstop: bin/shepherd-poke.sh \"doc-sup doc-writer\" 40 180 &"
