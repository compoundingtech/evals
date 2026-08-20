#!/usr/bin/env bash
set -euo pipefail

real="${ST2_REAL_BIN:?exact candidate st2 path required}"
root="${CATALOG:?CATALOG required}/.."
stream=''
event_id=''
previous=''
for argument in "$@"; do
  case "$previous" in
    --stream) stream="$argument" ;;
    --event-id) event_id="$argument" ;;
  esac
  previous="$argument"
done
test -n "$stream"
test -n "$event_id"

state="$root/injection-$stream.count"
count=0
test ! -e "$state" || count="$(cat "$state")"
count=$((count + 1))
printf '%s\n' "$count" >"$state"
payload_hash="$(printf '%s\0' "$@" | sha256sum | cut -d ' ' -f 1)"

if test "$count" -le 2; then
  printf '%s injected %s %s\n' "$count" "$event_id" "$payload_hash" >>"$root/injection-$stream.log"
  echo "injected transient event delivery failure $count" >&2
  exit 75
fi

printf '%s forwarded %s %s\n' "$count" "$event_id" "$payload_hash" >>"$root/injection-$stream.log"
exec "$real" "$@"
