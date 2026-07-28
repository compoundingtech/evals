#!/usr/bin/env bash
set -euo pipefail

net="${CATALOG:?CATALOG must be set}/net"
good="$net/good-workspace"
bad="$net/bad-workspace"

test "$(cat "$good/.st2/copied.txt")" = "COPY-64ce"
test "$(cat "$good/.st2/generated.txt")" = "AGENT=evalhost.good"
jq -e '.base == "kept" and .nested.left == 1 and .nested.right == 2' \
  "$good/.st2/settings.json" >/dev/null
test "$(grep -Fxc LINE-64ce "$good/.st2/rules.txt")" -eq 1
grep -Fqx '.st2/' "$good/.git/info/exclude"
echo "ALL-DIRECTIVES-GREEN-64ce"

git -C "$good" diff --quiet -- README.md
grep -Fqx '# Render safety control' "$good/README.md"
echo "IDENTICAL-TRACKED-GREEN-64ce"

git -C "$bad" diff --quiet -- README.md
grep -Fqx '# Render safety control' "$bad/README.md"
test ! -e "$bad/.st2/should-not-exist"
echo "CHANGED-TRACKED-BLOCKED-64ce"

test -f "$good/.st2/copied.txt"
echo "PEER-MATERIALIZED-GREEN-64ce"
