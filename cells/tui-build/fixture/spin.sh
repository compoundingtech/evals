#!/usr/bin/env bash
# Spin the tui-build cell: tui-sup (bypass, integration lead) + tui-tree / tui-cards (auto, own a view
# each) + tui-ux (auto, usability reviewer, no code). Run AFTER setup-sandbox.sh. Composes personas,
# wires coord+asyncRewake+pre-trust, seeds the hermetic build request into tui-sup's inbox, and launches
# (workers first, supervisor last). Claude agents auto-wake via asyncRewake but still need shepherd-poke.sh
# as an HB-4 backstop.
#
#   ./spin.sh [SANDBOX]     # default: ${EVAL_SANDBOX:-./.sandbox}/tui-build
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SB="${1:-${EVAL_SANDBOX:-./.sandbox}/tui-build}"
ROOT="${ST_ROOT:-${XDG_STATE_HOME:-$HOME/.local/state}/smalltalk}"

[ -d "$SB/sup" ] || { echo "== sandbox absent — materializing =="; "$HERE/setup-sandbox.sh" "$SB"; }

echo "== 1/4  compose personas (CLAUDE.md) =="
for r in sup tree cards ux; do "$HERE/compose-persona.sh" "$r" "$SB" >/dev/null && echo "   composed tui-$r"; done

echo "== 2/4  wire agents (sup=bypass, tree/cards/ux=auto) =="
for r in sup tree cards ux; do "$HERE/configure-claude-agent.sh" "$r" "$SB"; done

echo "== 3/4  seed the hermetic build request into tui-sup's inbox (boot-time ms; strip HTML header) =="
ms=$(( $(date +%s) * 1000 ))
sfx="$(printf '%06x' "$(( (RANDOM << 8 ^ RANDOM) & 0xffffff ))")"
sed -n '/^---$/,$p' "$HERE/kick-supervisor.md" > "$ROOT/tui-sup/inbox/${ms}-${sfx}.md"
echo "   seeded $ROOT/tui-sup/inbox/${ms}-${sfx}.md"

echo "== 4/4  launch (pty up) — workers first, supervisor last =="
for r in tree cards ux sup; do echo "   pty up in $SB/$r"; ( cd "$SB/$r" && pty up ); done

echo
echo "SPUN (tui-build cell). sessions:"; pty ls 2>/dev/null | grep -E "tui-(sup|tree|cards|ux)-" || pty ls 2>/dev/null || true
echo
echo "OBSERVE the coord thread: tui-sup builds the shared data layer (src/data/network.ts → coord agents"
echo "  --enrich --json, read-only) -> briefs tui-tree + tui-cards to wire their views to it -> briefs"
echo "  tui-ux for the usability pass -> integrates -> drives the find→fix loop (ux finds, the view owner"
echo "  fixes, re-verify) -> reports to river. The built viz reads the FROZEN fixture:"
echo "     ST_ROOT=$SB/fixture/smalltalk npm start   (and npm run cards)"
echo
echo "WAKE: asyncRewake is primary. HB-4 backstop if agents idle on delivered messages:"
echo "  bin/shepherd-poke.sh \"tui-sup tui-tree tui-cards tui-ux\" 40 240 &"
echo
echo "GRADE when the build closes:  fixture/grade.sh \"$SB\""
echo "TEARDOWN after grading: neuter each pty.toml -> .done, \`pty kill\`/\`pty rm\` the sessions, remove \$SB."
