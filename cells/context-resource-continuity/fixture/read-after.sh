#!/usr/bin/env bash
set -euo pipefail

net="${CATALOG:?CATALOG must be set}/net"
ref="$(cat "$CATALOG/resource-ref")"
st2 context read cr.agent --catalog "$net" --full
st2 resource read cr.agent "$ref" --catalog "$net"
