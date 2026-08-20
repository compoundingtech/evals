#!/usr/bin/env bash
set -euo pipefail

stream="${1:?stream name required}"
marker="${CATALOG:?CATALOG required}/../adapter-$stream.json"
st2 event emit "${ST_AGENT:?ST_AGENT required}" \
  --stream "$stream" \
  --event-id "$stream-delivery-1" \
  --subject "$stream adapter" \
  --message "payload from $stream" \
  --host stream \
  --json >"$marker"
exec sleep 300
