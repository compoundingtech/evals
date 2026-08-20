#!/usr/bin/env bash
set -euo pipefail

root="${CATALOG:?CATALOG must be set}"
net="$root/net"
export CATALOG="$net"
export ST_ROOT="$net"
export PTY_ROOT="$net/pty"
export XDG_STATE_HOME="$root/state"
export ST2_REAL_BIN="$(command -v st2)"
export ST2_EVENT_BIN="$root/inject-event-failures.sh"
printf '%s\n' "$(date +%s%N)-$$" >"$root/run-id"

cleanup() {
  st2 down --catalog "$net" --host stream >/dev/null 2>&1 || true
  PTY_ROOT="$PTY_ROOT" pty rm stream.nix-watcher >/dev/null 2>&1 || true
}
trap cleanup EXIT

st2 validate --catalog "$net" --host stream --strict >/dev/null
st2 up --once --catalog "$net" --host stream >"$root/up.out"
grep -Fq 'stream.nix-watcher.stream-nix-success' "$root/up.out"
grep -Fq 'stream.nix-watcher.stream-nix-failure' "$root/up.out"

for mode in success failure; do
  for _ in $(seq 1 200); do
    test -s "$root/nix-$mode.started" && break
    sleep 0.05
  done
  test -s "$root/nix-$mode.started"
  test ! -e "$root/nix-$mode.events.jsonl"
done
st2 tasks --catalog "$net" --host stream --json >"$root/tasks-waiting.json"
jq -e '
  [.tasks[] | select(.task == "stream-nix-success" or .task == "stream-nix-failure")]
  | length == 2 and all(.runtime.state == "running")
' "$root/tasks-waiting.json" >/dev/null
echo "STREAM-NIX-WAITING-GREEN-4d91"

for mode in success failure; do
  for _ in $(seq 1 1200); do
    test -s "$root/nix-$mode.events.jsonl" && break
    sleep 0.05
  done
  test -s "$root/nix-$mode.events.jsonl"
  started="$(cat "$root/nix-$mode.started")"
  finished="$(cat "$root/nix-$mode.finished")"
  test $((finished - started)) -ge 1800000000
done
jq -e '.terminal == "success" and .buildStatus == 0 and .first.status == "created"' \
  "$root/nix-success.events.jsonl" >/dev/null
jq -e '.terminal == "failure" and .buildStatus == 1 and .first.status == "created"' \
  "$root/nix-failure.events.jsonl" >/dev/null
grep -Fq 'intentional-nix-waiter-failure' "$root/nix-failure.build.log"
echo "STREAM-NIX-TERMINALS-GREEN-4d91"

for mode in success failure; do
  test "$(sed -n '1,3p' "$root/injection-nix-$mode.log" | wc -l)" -eq 3
  test "$(sed -n '1,3p' "$root/injection-nix-$mode.log" | awk '{print $4}' | sort -u | wc -l)" -eq 1
  grep -Eq '^1 injected ' "$root/injection-nix-$mode.log"
  grep -Eq '^2 injected ' "$root/injection-nix-$mode.log"
  grep -Eq '^3 forwarded ' "$root/injection-nix-$mode.log"
  jq -e '
    .retry.status == "deduplicated" and
    .retry.filename == .first.filename and
    .retry.recipient == "stream.nix-watcher"
  ' "$root/nix-$mode.events.jsonl" >/dev/null
done
st2 tasks --catalog "$net" --host stream --json >"$root/tasks-after-retry.json"
jq -e '
  [.tasks[] | select(.task == "stream-nix-success" or .task == "stream-nix-failure")]
  | length == 2 and all(.runtime.state == "running")
' "$root/tasks-after-retry.json" >/dev/null
inbox="$net/agents/stream/nix-watcher/resources/inbox"
test "$(find "$inbox" -maxdepth 1 -type f -name '*.md' | wc -l)" -eq 2

# Model a supervisor restart after an uncertain acknowledgement. The adapter
# derives its event identity from the stable build request, not its process ID.
st2 down --catalog "$net" --host stream >/dev/null
st2 up --once --catalog "$net" --host stream >"$root/restart-up.out"
for mode in success failure; do
  for _ in $(seq 1 1200); do
    test "$(wc -l <"$root/nix-$mode.events.jsonl")" -ge 2 && break
    sleep 0.05
  done
  test "$(wc -l <"$root/nix-$mode.events.jsonl")" -eq 2
  jq -se '
    .[1].first.status == "deduplicated" and
    .[1].first.filename == .[0].first.filename and
    .[1].retry.status == "deduplicated"
  ' "$root/nix-$mode.events.jsonl" >/dev/null
done
test "$(find "$inbox" -maxdepth 1 -type f -name '*.md' | wc -l)" -eq 2
echo "STREAM-NIX-RETRY-GREEN-4d91"

st2 down --catalog "$net" --host stream >/dev/null
PTY_ROOT="$PTY_ROOT" pty rm stream.nix-watcher >/dev/null 2>&1 || true
trap - EXIT
test "$(PTY_ROOT="$PTY_ROOT" pty list --json | jq 'length')" -eq 0
st2 tasks --catalog "$net" --host stream --json >"$root/tasks-clean.json"
jq -e '.tasks | all(.runtime.state != "running")' "$root/tasks-clean.json" >/dev/null
echo "STREAM-NIX-CLEANUP-GREEN-4d91"
