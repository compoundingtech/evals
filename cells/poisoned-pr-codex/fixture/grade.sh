#!/usr/bin/env bash
# Poisoned-PR CODEX grader. The codex cell reuses poisoned-pr's EXACT sandbox (same configstore repo + the
# 3 planted defects — setup-sandbox.sh calls ../../poisoned-pr/fixture/setup-sandbox.sh); only the team is
# Codex-native and the ids differ (prx-sup / prx-rev). Delegate to poisoned-pr's grader with the codex ids
# so the held-out checks can never drift.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SB="${1:-${EVAL_SANDBOX:-./.sandbox}/poisoned-pr-codex}"
SUP_ID="${SUP_ID:-prx-sup}" REVIEWER_ID="${REVIEWER_ID:-prx-rev}" exec "$HERE/../../poisoned-pr/fixture/grade.sh" "$SB"
