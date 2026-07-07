#!/usr/bin/env bash
# Spin the Ghost-bug CODEX cell (full-Codex debug: gbx-sup + gbx-fix). Run AFTER setup-sandbox.sh.
# Wires codex+ding for both, seeds the hermetic kick into gbx-sup's inbox, launches (worker first).
# Codex wakes via `ding` (not shepherd-poke); it has no auto-boot-ritual, so expect to nudge the sup
# to start and the worker on each delegation round (the Codex wake tax).
#
#   ./spin.sh            # sandbox defaults to ${EVAL_SANDBOX:-./.sandbox}/ghost-bug-codex
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/../../../bin/lib-harness.sh"
SB="${1:-${EVAL_SANDBOX:-./.sandbox}/ghost-bug-codex}"
stev_init "$(basename "$(dirname "$HERE")")" "$SB"; export PTY_ROOT="$(stev_pty_root "$SB")"; stev_arm_teardown "$SB"  # stev-retirement: export the run's decoupled PTY_ROOT (#69) -> `pty up` lands every session in it
ROOT="${ST_ROOT:-${XDG_STATE_HOME:-$HOME/.local/state}/smalltalk}"

echo "== 1/3  wire codex + ding for both agents =="
"$HERE/configure-codex-agent.sh" sup "$SB"
"$HERE/configure-codex-agent.sh" fix "$SB"

echo "== 2/3  seed the hermetic kick into gbx-sup's inbox =="
ms=$(( $(date +%s) * 1000 ))
sfx="$(printf '%06x' "$(( (RANDOM << 8 ^ RANDOM) & 0xffffff ))")"
sed -n '/^---$/,$p' "$HERE/kick-supervisor.md" > "$ROOT/gbx-sup/inbox/${ms}-${sfx}.md"
echo "   seeded $ROOT/gbx-sup/inbox/${ms}-${sfx}.md"

echo "== 3/3  launch (pty up) — worker first, supervisor last =="
for pair in "fix:$SB/worker" "sup:$SB/sup"; do
  d="${pair#*:}"; echo "   pty up in $d"; ( cd "$d" && pty --root "$PTY_ROOT" up )
done

echo
echo "SPUN (Codex Ghost-bug cell). sessions:"; pty --root "$PTY_ROOT" ls 2>/dev/null | grep -E 'gbx-(sup|fix)' || pty --root "$PTY_ROOT" ls 2>/dev/null
echo
echo "OBSERVE: kick -> gbx-sup delegate -> gbx-fix reproduce+root-cause+fix+regression-test+report -> gbx-sup verify -> confirm."
echo "Codex wake: nudge gbx-sup to boot (no auto-boot-ritual); ding wakes on NEW messages but misses pre-seeded/restart-window."
