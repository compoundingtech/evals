#!/usr/bin/env bash
# Launch the ding-reply agent via REAL convoy — `convoy add` is DING-DEFAULT (no MCP), the exact no-MCP
# shape the removed `st launch claude --ding` provided. `stev_convoy_add` (lib-harness) does the pre-trust
# + `convoy add` (correct-by-construction: DING-BUS.md + hooks + pty.toml + persona + `st ding` sidecar) on
# the ISOLATED network ($ST_ROOT, exported by spin.sh). The single agent (dr-agent, auto) receives the kick
# via ding and must REPLY on the thread via the `st` CLI.
#   ./configure-claude-agent.sh [SANDBOX]   # spin.sh must convoy-init + export ST_ROOT=$NET first
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/../../../bin/lib-harness.sh"
SB="${1:-${EVAL_SANDBOX:-./.sandbox}/ding-reply}"
stev_convoy_add "dr-agent" "$SB/work" "auto" "$SB/personas-local/dr-agent.md"
