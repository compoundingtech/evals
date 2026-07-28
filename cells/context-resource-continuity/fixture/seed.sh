#!/usr/bin/env bash
set -euo pipefail

net="${CATALOG:?CATALOG must be set}/net"
printf '%s\n' "CONTEXT-NOW-7b9d" | st2 context write cr.agent --catalog "$net" --as cr.agent
st2 context append cr.agent --catalog "$net" --as cr.agent \
  --decision "DECISION-7b9d" --why "DECISION-WHY-7b9d"
st2 resource add https://example.invalid/context-resource-7b9d \
  --catalog "$net" --as cr.agent --title "CONTINUITY-RESOURCE-7b9d" \
  --tag continuity,restart --relation output >"$CATALOG/resource-ref"
test -s "$CATALOG/resource-ref"
echo "STATE-SEEDED-7b9d"
