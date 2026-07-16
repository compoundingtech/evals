#!/usr/bin/env bash
# Spin the compose-config-load cell via REAL convoy (convoy add, ding-default): one worker (ccl) composed INTO a
# repo whose own CLAUDE.md carries a secret + a project greet skill. The live headline proves the agent LOADS +
# FOLLOWS both through the compose: on the kick it writes SECRET.txt (the secret from its repo CLAUDE.md — proving
# CLAUDE.md loaded through convoy's additive CLAUDE.local.md layering, not clobbered) and GREET.txt (via the greet
# skill — proving the project skill loaded). Tokens live ONLY in those file bodies, never in the kick.
# SELF-ISOLATING: isolated convoy net at $SB/net + a decoupled short PTY_ROOT.
#   ./spin.sh [SANDBOX]        # sandbox defaults to ${EVAL_SANDBOX:-/tmp}/ccl
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/../../../bin/lib-harness.sh"
SB="${1:-${EVAL_SANDBOX:-/tmp}/ccl}"
NET="$SB/net"; export ST_ROOT="$NET"

[ -d "$SB/repo/.git" ] || { echo "== sandbox absent — materializing =="; "$HERE/setup-sandbox.sh" "$SB" >/dev/null; }

stev_init "compose-config-load" "$SB"
export PTY_ROOT="$(stev_pty_root "$SB")"

STEV_NET="$NET"
trap 'rc=$?; [ "$rc" = 0 ] || { echo "== spin rc=$rc — tearing down the isolated net ==" >&2; stev_convoy_teardown "$STEV_NET"; stev_teardown "$SB"; }' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

echo "== 1/4  convoy init the isolated network ($NET) =="
stev_convoy_init "$NET"

echo "== 2/4  compose persona (names no tokens) =="
"$HERE/compose-persona.sh" "$SB"

echo "== 3/4  convoy add ccl INTO the repo (auto; CLAUDE.md + project skill auto-load via --dir) =="
convoy pretrust "$SB/repo" >/dev/null 2>&1 || true
"$HERE/configure-claude-agent.sh" "$SB"

echo "== 4/4  seed the check kick into ccl's inbox (delivered by the ding sidecar) =="
mkdir -p "$NET/ccl/inbox"
ms=$(( $(date +%s) * 1000 )); sfx="$(printf '%06x' "$(( (RANDOM << 8 ^ RANDOM) & 0xffffff ))")"
sed -n '/^---$/,$p' "$HERE/kick.md" > "$NET/ccl/inbox/${ms}-${sfx}.md"
echo "   kick seeded $NET/ccl/inbox/${ms}-${sfx}.md (names no tokens — the worker must load CLAUDE.md + the skill)"

echo
echo "SPUN (compose-config-load, isolated convoy net $NET). members:"; convoy ls "$NET" 2>/dev/null | grep -E 'ccl' || convoy ls "$NET" 2>/dev/null
echo "OBSERVE (ST_ROOT=$NET): ccl boots -> writes SECRET.txt (secret from its repo CLAUDE.md, loaded through the"
echo "  compose) + GREET.txt (via its greet skill). A sentinel with the right token PROVES that config loaded."
echo "GRADE after it settles:  $HERE/grade.sh \"$SB\"   (run probe.sh too for the box-free deterministic gates)"
echo "TEARDOWN after grading:  bin/st-evals teardown \"$SB\"   (or: convoy down \"$NET\" --force; rm -rf \"$SB\")"
