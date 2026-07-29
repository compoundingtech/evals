#!/usr/bin/env bash
set -euo pipefail

test "$(cat "$CATALOG/results/head-before.code")" = 0
test "$(cat "$CATALOG/results/head-after.code")" = 0
jq -e '. == null' "$CATALOG/results/head-before.json" >/dev/null
jq -e '. == null' "$CATALOG/results/head-after.json" >/dev/null

for result in publish-a replay-a publish-b publish-a2 replay-a2; do
  jq -e '.rootChanged == false' "$CATALOG/results/$result.json" >/dev/null
done
