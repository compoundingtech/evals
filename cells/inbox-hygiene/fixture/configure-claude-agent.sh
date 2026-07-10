#!/usr/bin/env bash
# Launch the single inbox-hygiene agent via REAL convoy (convoy add, ding-default). stev_convoy_add does
# pre-trust + convoy add --network on the ISOLATED net ($ST_ROOT, exported by spin.sh).
#   ./configure-claude-agent.sh [SANDBOX]
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/../../../bin/lib-harness.sh"
SB="${1:-${EVAL_SANDBOX:-./.sandbox}/inbox-hygiene}"
stev_convoy_add "ih-agent" "$SB/repo" "auto" "$SB/personas-local/ih-agent.md"
