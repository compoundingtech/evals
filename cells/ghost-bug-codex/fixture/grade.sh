#!/usr/bin/env bash
# Ghost-bug CODEX grader. The codex cell reuses ghost-bug's EXACT sandbox (same labelkit + ghost mutation
# bug — see setup-sandbox.sh, which calls ../../ghost-bug/fixture/setup-sandbox.sh); only the team is
# Codex-native and the ids/author differ (gbx-sup / gbx-fix). Delegate to ghost-bug's grader with the codex
# ids so the held-out checks can never drift between the two variants.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SB="${1:-${EVAL_SANDBOX:-./.sandbox}/ghost-bug-codex}"
SUP_ID="${SUP_ID:-gbx-sup}" WORKER_ID="${WORKER_ID:-gbx-fix}" exec "$HERE/../../ghost-bug/fixture/grade.sh" "$SB"
