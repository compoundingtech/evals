#!/usr/bin/env bash
set -euo pipefail

spec="${CATALOG:?CATALOG must be set}/warnings/agents/val/warn/agent.kdl"
workspace="$CATALOG/warnings/workspace"
sed -i "s#__WORKSPACE__#$workspace#" "$spec"
grep -Fq "workspace \"$workspace\"" "$spec"
