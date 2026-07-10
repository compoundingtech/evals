#!/usr/bin/env bash
# Launch the TEAM-STANDUP CoS via REAL convoy (`convoy add` supervisor, ding-default). This is the SAME
# path a human uses to stand up a chief-of-staff, so the eval dogfoods the real launch surface. The CoS
# then stands up taskflow-dev ITSELF via `convoy add` during the run (that IS the P5 test). `stev_convoy_add`
# does the pre-trust + `convoy add` on the ISOLATED net ($ST_ROOT, exported by spin.sh); convoy writes the
# CoS's DING-BUS.md + hooks + pty.toml + persona + `st ding` sidecar.
# Posture: CoS = bypassPermissions (spawn-capable — it runs `convoy add` to stand up the worker).
#   ./configure-claude-agent.sh [SANDBOX]   # spin.sh must convoy-init + export ST_ROOT=$NET first
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/../../../bin/lib-harness.sh"
SB="${1:-${EVAL_SANDBOX:-./.sandbox}/team-standup}"
stev_convoy_add "ts-cos" "$SB/cos" "bypassPermissions" "$SB/personas-local/ts-cos.md"
