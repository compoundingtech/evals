#!/usr/bin/env bash
set -euo pipefail
object_path=$(jq -er .objectPath "$CATALOG/results/prepare.json")
test -f "$object_path"
cmp "$CATALOG/expected/agent.kdl" "$object_path"
