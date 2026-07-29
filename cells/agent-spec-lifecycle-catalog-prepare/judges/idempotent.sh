#!/usr/bin/env bash
set -euo pipefail
test "$(cat "$CATALOG/results/prepare-again.code")" = 0
a=$(jq -er .object "$CATALOG/results/prepare.json")
b=$(jq -er .object "$CATALOG/results/prepare-again.json")
test "$a" = "$b"
