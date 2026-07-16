#!/usr/bin/env bash
# Launch the compose-config-load worker (ccl) via REAL convoy (convoy add, ding-default) on the ISOLATED net
# ($ST_ROOT, exported by spin.sh). No --plugin-dir needed: the greet skill is PROJECT scope in the repo, so it
# auto-loads via --dir; the repo's own CLAUDE.md loads through convoy's additive CLAUDE.local.md layering.
#   ./configure-claude-agent.sh [SANDBOX]
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/../../../bin/lib-harness.sh"
SB="${1:-${EVAL_SANDBOX:-/tmp}/ccl}"
: "${ST_ROOT:?configure: export ST_ROOT (spin.sh does)}"
stev_convoy_add "ccl" "$SB/repo" "auto" "$SB/personas-local/ccl.md"
