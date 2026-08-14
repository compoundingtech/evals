#!/usr/bin/env bash
set -euo pipefail

mode="${1:?mode is required}"
store="${2:?session store is required}"
durable="${3:?durable marker is required}"
receipt="${4:?launch receipt is required}"
requested_session="${5:-}"

test "$(<"$durable")" = "DURABLE-WORK-CONTINUES-8d31"
mkdir -p "$store"

fresh_uuid() {
  seed="$(date +%s%N)-$$-$RANDOM-$store"
  hex="$(printf '%s' "$seed" | sha256sum | cut -c1-32)"
  printf '%s-%s-4%s-a%s-%s\n' \
    "${hex:0:8}" "${hex:8:4}" "${hex:13:3}" "${hex:17:3}" "${hex:20:12}"
}

case "$mode" in
  start)
    session="$(fresh_uuid)"
    printf '{"type":"conversation","sessionId":"%s","turn":"created"}\n' "$session" \
      > "$store/$session.jsonl"
    ;;
  resume)
    session="${requested_session:?resume session is required}"
    test -f "$store/$session.jsonl"
    printf '{"type":"conversation","sessionId":"%s","turn":"resumed"}\n' "$session" \
      >> "$store/$session.jsonl"
    ;;
  legacy)
    session="-"
    ;;
  *)
    printf 'unknown adapter mode: %s\n' "$mode" >&2
    exit 2
    ;;
esac

printf '%s\t%s\t%s\t%s\n' "$mode" "$session" "$(<"$durable")" "$$" > "$receipt"
exec tail -f /dev/null
