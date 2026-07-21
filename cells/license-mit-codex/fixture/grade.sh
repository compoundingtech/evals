#!/usr/bin/env bash
# license-mit CODEX grader. The codex cell reuses license-mit's EXACT sandbox (setup-sandbox.sh calls
# ../../license-mit/fixture/setup-sandbox.sh); only the team is Codex-native and the ids differ (lmc-sup /
# lmc-worker). Delegate to license-mit's grader with the codex ids so the held-out checks never drift.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SB="${1:-${EVAL_SANDBOX:-./.sandbox}/license-mit-codex}"
SUP_ID="${SUP_ID:-lmc-sup}" WORKER_ID="${WORKER_ID:-lmc-worker}" exec "$HERE/../../license-mit/fixture/grade.sh" "$SB"
