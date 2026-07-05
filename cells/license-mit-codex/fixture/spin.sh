#!/usr/bin/env bash
# Spin the license-mit CODEX cell (full-Codex team: lmc-sup + lmc-worker). Run AFTER setup-sandbox.sh.
# Wires codex+ding for both, seeds the MIT-license kick into lmc-sup's inbox, launches (worker first).
# Codex wakes via ding (no asyncRewake) + needs a boot nudge; the stev harness names + tears down sessions.
#   ./spin.sh            # sandbox defaults to ${EVAL_SANDBOX:-./.sandbox}/license-mit-codex
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/../../../bin/lib-harness.sh"
SB="${1:-${EVAL_SANDBOX:-./.sandbox}/license-mit-codex}"
stev_init "$(basename "$(dirname "$HERE")")" "$SB"; stev_arm_teardown "$SB"
ROOT="${ST_ROOT:-${XDG_STATE_HOME:-$HOME/.local/state}/smalltalk}"

echo "== 1/3  wire codex + ding for both =="
"$HERE/configure-codex-agent.sh" sup    "$SB"
"$HERE/configure-codex-agent.sh" worker "$SB"

echo "== 2/3  seed the MIT-license kick into lmc-sup's inbox (boot-time ms; strip HTML header) =="
ms=$(( $(date +%s) * 1000 )); sfx="$(printf '%06x' "$(( (RANDOM << 8 ^ RANDOM) & 0xffffff ))")"
sed -n '/^---$/,$p' "$HERE/kick-supervisor.md" > "$ROOT/lmc-sup/inbox/${ms}-${sfx}.md"
echo "   seeded $ROOT/lmc-sup/inbox/${ms}-${sfx}.md"

echo "== 3/3  launch — worker first, supervisor last =="
for pair in "worker:$SB/worker" "sup:$SB/sup"; do d="${pair#*:}"; echo "   pty up in $d"; ( cd "$d" && pty up ); done

echo
echo "SPUN (Codex license-mit cell). sessions:"; pty ls 2>/dev/null | grep -E "stev-license-mit-codex-" || pty ls 2>/dev/null || true
echo "OBSERVE: kick -> lmc-sup delegate -> lmc-worker changes LICENSE->MIT + commits -> reports -> lmc-sup"
echo "         verifies read-only -> confirms to eval-runner. HARD GATE: only lmc-worker commits to the widget repo."
echo "Codex wake: ding wakes on NEW messages (no shepherd-poke); nudge lmc-sup to boot if it idles."
echo "GRADE, then TEARDOWN:  bin/st-evals teardown \"$SB\"   (kills+rm's every stev session, zero orphans)"
