#!/usr/bin/env bash
set -euo pipefail

mode="${1:?success or failure required}"
case "$mode" in
  success|failure) ;;
  *) echo "unsupported waiter mode: $mode" >&2; exit 64 ;;
esac

root="${CATALOG:?CATALOG required}/.."
started="$root/nix-$mode.started"
finished="$root/nix-$mode.finished"
result="$root/nix-$mode.events.jsonl"
build_log="$root/nix-$mode.build.log"
nonce="$(cat "$root/run-id")"
printf '%s\n' "$(date +%s%N)" >"$started"

if test "$mode" = success; then
  build_body='sleep 2; printf success > $out'
  expected_status=0
  terminal=success
else
  build_body='sleep 2; echo intentional-nix-waiter-failure >&2; exit 23'
  expected_status=1
  terminal=failure
fi

set +e
nix-build --no-out-link --option substitute false --expr \
  "with import <nixpkgs> {}; runCommand \"st2-stream-e2e-$mode-$nonce\" {} ''$build_body''" \
  >"$build_log" 2>&1
build_status="$?"
set -e

if test "$build_status" -ne "$expected_status"; then
  printf 'unexpected nix-build status: got %s, expected %s\n' "$build_status" "$expected_status" >&2
  cat "$build_log" >&2
  exit 1
fi

event_id="nix-$mode-terminal-$nonce"
subject="Nix build $terminal"
message="real Nix build reached terminal status $terminal"
event_bin="${ST2_EVENT_BIN:-st2}"
emit_terminal() {
  "$event_bin" event emit "${ST_AGENT:?ST_AGENT required}" \
    --stream "nix-$mode" \
    --event-id "$event_id" \
    --key "$mode" \
    --subject "$subject" \
    --message "$message" \
    --host stream \
    --json
}

first=''
delay=0.05
for attempt in 1 2 3 4 5; do
  set +e
  first="$(emit_terminal 2>>"$root/nix-$mode.emit.err")"
  emit_status="$?"
  set -e
  test "$emit_status" -eq 0 && break
  if test "$attempt" -eq 5; then
    echo "terminal event delivery exhausted after $attempt attempts" >&2
    exit "$emit_status"
  fi
  sleep "$delay"
  delay="$(awk -v delay="$delay" 'BEGIN { printf "%.2f", delay * 2 }')"
done

retry="$("$event_bin" event emit "$ST_AGENT" \
  --stream "nix-$mode" \
  --event-id "$event_id" \
  --key "$mode" \
  --subject "$subject" \
  --message "$message" \
  --host stream \
  --json)"
jq -cn --argjson first "$first" --argjson retry "$retry" \
  --arg terminal "$terminal" --argjson buildStatus "$build_status" \
  '{first:$first,retry:$retry,terminal:$terminal,buildStatus:$buildStatus}' >>"$result"
printf '%s\n' "$(date +%s%N)" >"$finished"

# Keep the adapter supervised after delivering its terminal edge; reconciliation
# must not turn a completed one-shot waiter into an emission loop.
exec sleep 300
