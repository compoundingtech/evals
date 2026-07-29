#!/usr/bin/env bash
set -euo pipefail
test "$(cat "$CATALOG/results/replay-a.code")" = 0
test "$(jq -er .refCommit "$CATALOG/results/publish-a.json")" = \
  "$(jq -er .refCommit "$CATALOG/results/replay-a.json")"
test "$(jq -er .resourceBindingCommit "$CATALOG/results/publish-a.json")" = \
  "$(jq -er .resourceBindingCommit "$CATALOG/results/replay-a.json")"
