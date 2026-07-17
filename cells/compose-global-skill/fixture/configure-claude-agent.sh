#!/usr/bin/env bash
# Launch a compose-global-skill agent via REAL convoy on the DEFAULT config dir — so real keychain auth works and
# the agent sees the user's GLOBAL ~/.claude/skills (read-only; the eval never modifies them). No --config-dir, no
# API key: Nathan's read-only existing-skill approach dodges the auth wall entirely.
#   ./configure-claude-agent.sh [SANDBOX] [ID] [DIR]   # defaults: ID=gsw DIR=$SB/repo (control: gsnc + $SB/control)
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/../../../bin/lib-harness.sh"
SB="${1:-${EVAL_SANDBOX:-/tmp}/gs}"; id="${2:-gsw}"; dir="${3:-$SB/repo}"
: "${ST_ROOT:?configure: export ST_ROOT (spin.sh does)}"
stev_convoy_add "$id" "$dir" "auto" "$SB/personas-local/$id.md"
