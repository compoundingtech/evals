#!/usr/bin/env bash
set -euo pipefail

scenario="${1:?scenario required}"
out="${2:?output root required}"
axe="${AXE_AGENT_NEW_SUCCESSOR:?pin AXE_AGENT_NEW_SUCCESSOR to the successor Axe executable}"
commit="${AXE_AGENT_NEW_SUCCESSOR_COMMIT:?pin AXE_AGENT_NEW_SUCCESSOR_COMMIT}"
driver="${AXE_AGENT_NEW_LIFECYCLE_DRIVER:?pin AXE_AGENT_NEW_LIFECYCLE_DRIVER}"

case "$axe:$driver" in
  /*:/*) ;;
  *) echo "successor Axe and lifecycle driver must be absolute paths" >&2; exit 1 ;;
esac
[[ "$commit" =~ ^[0-9a-f]{40}$ ]] || {
  echo "successor commit must be exact 40-hex" >&2
  exit 1
}
test -x "$axe"
test -x "$driver"

mkdir -p "$out"
"$driver" \
  --axe "$axe" \
  --axe-source-commit "$commit" \
  --scenario "$scenario" \
  --output "$out"
bash ./inspect-case.sh "$scenario" "$out"
