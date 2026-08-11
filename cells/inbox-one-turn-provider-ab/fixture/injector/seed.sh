#!/usr/bin/env bash
set -euo pipefail

export ST_AGENT=iot.injector
for target in iot.claude iot.codex; do
  st2 message send "$target" --root "$CATALOG" --as iot.injector --subject "cold backlog A" \
    -m 'Reply on this thread with exactly `ACK IOT-COLD-A-4d91`, then archive this message.' >/dev/null
  st2 message send "$target" --root "$CATALOG" --as iot.injector --subject "cold backlog B" \
    -m 'Reply on this thread with exactly `ACK IOT-COLD-B-7a2c`, then archive this message.' >/dev/null
done
