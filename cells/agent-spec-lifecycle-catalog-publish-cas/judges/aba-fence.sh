#!/usr/bin/env bash
set -euo pipefail
test "$(cat "$CATALOG/results/publish-b.code")" = 0
test "$(cat "$CATALOG/results/publish-a2.code")" = 0
test "$(cat "$CATALOG/results/stale.code")" != 0
test "$(cat "$CATALOG/results/replay-a2.code")" = 0
test "$(jq -er .refCommit "$CATALOG/results/replay-a2.json")" = \
  "$(cat "$CATALOG/results/expected-final-ref")"
