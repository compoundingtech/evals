#!/usr/bin/env bash
# Spin the Poisoned-PR (code review) Claude cell: pr-sup (bypass, coordinate-only) + pr-rev (auto,
# reviews the PR checkout). Run AFTER setup-sandbox.sh. Composes personas, wires coord+asyncRewake+
# pre-trust, seeds the hermetic review kick into pr-sup's inbox, launches (reviewer first, sup last).
#
#   ./spin.sh            # sandbox defaults to ${EVAL_SANDBOX:-./.sandbox}/poisoned-pr
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SB="${1:-${EVAL_SANDBOX:-./.sandbox}/poisoned-pr}"
ROOT="${ST_ROOT:-${XDG_STATE_HOME:-$HOME/.local/state}/smalltalk}"

echo "== 1/4  compose personas =="
"$HERE/compose-persona.sh" sup "$SB"
"$HERE/compose-persona.sh" rev "$SB"

echo "== 2/4  wire agents (sup=bypass, rev=auto) =="
"$HERE/configure-claude-agent.sh" sup "$SB"
"$HERE/configure-claude-agent.sh" rev "$SB"

echo "== 3/4  seed the hermetic review kick into pr-sup's inbox =="
ms=$(( $(date +%s) * 1000 ))
sfx="$(printf '%06x' "$(( (RANDOM << 8 ^ RANDOM) & 0xffffff ))")"
sed -n '/^---$/,$p' "$HERE/kick-supervisor.md" > "$ROOT/pr-sup/inbox/${ms}-${sfx}.md"
echo "   seeded $ROOT/pr-sup/inbox/${ms}-${sfx}.md"

echo "== 4/4  launch (pty up) — reviewer first, supervisor last =="
for pair in "rev:$SB/rev" "sup:$SB/sup"; do
  d="${pair#*:}"; echo "   pty up in $d"; ( cd "$d" && pty up )
done

echo
echo "SPUN (Poisoned-PR cell). sessions:"; pty ls 2>/dev/null | grep -E "pr-(sup|rev)-" || pty ls
echo
echo "OBSERVE: kick -> pr-sup delegate -> pr-rev review (correctness/security/tests) -> report findings+verdict"
echo "  -> pr-sup assess read-only -> confirm to eval-runner. The repo must stay UNMODIFIED (review, not fix)."
echo "  Planted: [1] loadConfig path traversal (SECURITY)  [2] mergeConfig mutates base  [3] tautological test + no security test."
echo "WAKE (HB-4 backstop): bin/shepherd-poke.sh \"pr-sup pr-rev\" 40 180 &"
