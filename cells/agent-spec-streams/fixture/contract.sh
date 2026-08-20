#!/usr/bin/env bash
set -euo pipefail

root="${CATALOG:?CATALOG must be set}"
net="$root/net"
spec="$net/agents/stream/worker/agent.kdl"
original="$root/agent-spec-streams.original"
export CATALOG="$net"
export ST_ROOT="$net"
export PTY_ROOT="$net/pty"
export XDG_STATE_HOME="$root/state"
cp "$spec" "$original"

cleanup() {
  cp "$original" "$spec" 2>/dev/null || true
  st2 down --catalog "$net" --host stream >/dev/null 2>&1 || true
  PTY_ROOT="$PTY_ROOT" pty rm stream.worker >/dev/null 2>&1 || true
}
trap cleanup EXIT

check_invalid() {
  local name="$1"
  local declaration="$2"
  local expected="$3"
  local catalog="$root/invalid-$name"
  mkdir -p "$catalog/agents/stream/worker"
  printf '%s\n' "$declaration" >"$catalog/agents/stream/worker/agent.kdl"
  set +e
  st2 validate --catalog "$catalog" --host stream --strict >"$root/invalid-$name.out" 2>&1
  local status="$?"
  set -e
  test "$status" -ne 0
  grep -Fq "$expected" "$root/invalid-$name.out"
}

check_invalid uppercase \
  'agent "worker" { host "stream"; command "true"; stream "Bad" {} }' \
  'must match'
check_invalid too-long \
  'agent "worker" { host "stream"; command "true"; stream "abcdefghijklmnopqrstuvwxyzabcdefghijklmno" {} }' \
  'must be 1..=40 characters'
check_invalid two-launches \
  'agent "worker" { host "stream"; command "true"; stream "ci" { command "a"; argv "b" } }' \
  'at most one of `command` or `argv`'
check_invalid interval \
  'agent "worker" { host "stream"; command "true"; stream "ci" { every "1m" } }' \
  'stream `every` is reserved'
check_invalid collision \
  'agent "worker" { host "stream"; command "true"; stream "ci" {}; exec "stream-ci" { command "true" } }' \
  'declares both `stream "ci"` and a task named `stream-ci`'
echo "STREAM-STRICT-SHAPE-GREEN-83a7"

st2 validate --catalog "$net" --host stream --strict >/dev/null
st2 tasks --catalog "$net" --host stream --json >"$root/tasks-before.json"
jq -e '
  [.tasks[] | select(.task | startswith("stream-")) | {task, runtimeId, kind}] == [
    {"task":"stream-argv","runtimeId":"stream.worker.stream-argv","kind":"exec"},
    {"task":"stream-shell","runtimeId":"stream.worker.stream-shell","kind":"exec"}
  ] and
  ([.tasks[].task] | index("stream-external")) == null
' "$root/tasks-before.json" >/dev/null
echo "STREAM-LOWERING-GREEN-83a7"

st2 up --once --catalog "$net" --host stream >"$root/up.out"
grep -Fq 'stream.worker.stream-argv' "$root/up.out"
grep -Fq 'stream.worker.stream-shell' "$root/up.out"
for marker in "$root/adapter-argv.json" "$root/adapter-shell.json"; do
  for _ in $(seq 1 100); do
    test -s "$marker" && break
    sleep 0.05
  done
  jq -e '.status == "created" and .recipient == "stream.worker"' "$marker" >/dev/null
done
echo "STREAM-ADAPTERS-GREEN-83a7"

first="$(st2 event emit stream.worker --stream external --event-id ext-1 --subject external --message payload --host stream --json)"
replay="$(st2 event emit stream.worker --stream external --event-id ext-1 --subject external --message payload --host stream --json)"
jq -e '.status == "created"' <<<"$first" >/dev/null
jq -e '.status == "deduplicated"' <<<"$replay" >/dev/null
test "$(jq -r .filename <<<"$first")" = "$(jq -r .filename <<<"$replay")"
set +e
st2 event emit stream.worker --stream external --event-id ext-1 --message changed --host stream --json >"$root/conflict.out" 2>&1
conflict_status="$?"
st2 event emit stream.worker --stream missing --event-id missing-1 --message payload --host stream --json >"$root/undeclared.out" 2>&1
undeclared_status="$?"
set -e
test "$conflict_status" -ne 0
test "$undeclared_status" -ne 0
grep -Fq 'reused with different content' "$root/conflict.out"
grep -Fq "does not declare stream 'missing'" "$root/undeclared.out"
echo "STREAM-INGRESS-GREEN-83a7"

st2 agent desired-state stream.worker suspended --reason "Acceptance hold" --host stream --json >"$root/suspend.json"
st2 up --once --catalog "$net" --host stream >"$root/suspended-up.out"
st2 tasks --catalog "$net" --host stream --json >"$root/tasks-suspended.json"
jq -e '.tasks | all(.desiredState == "absent" and .runtime.state != "running")' "$root/tasks-suspended.json" >/dev/null
set +e
st2 event emit stream.worker --stream external --event-id held-1 --message payload --host stream --json >"$root/suspended-event.out" 2>&1
suspended_status="$?"
set -e
test "$suspended_status" -ne 0
grep -Fq 'eyes are closed' "$root/suspended-event.out"
st2 agent desired-state stream.worker running --host stream --json >"$root/resume.json"
st2 up --once --catalog "$net" --host stream >"$root/resumed-up.out"
grep -Fq 'stream.worker.stream-argv' "$root/resumed-up.out"
grep -Fq 'stream.worker.stream-shell' "$root/resumed-up.out"
echo "STREAM-LIFECYCLE-GREEN-83a7"

st2 down --catalog "$net" --host stream >/dev/null
PTY_ROOT="$PTY_ROOT" pty rm stream.worker >/dev/null 2>&1 || true
cp "$original" "$spec"
trap - EXIT
test "$(PTY_ROOT="$PTY_ROOT" pty list --json | jq 'length')" -eq 0
st2 tasks --catalog "$net" --host stream --json >"$root/tasks-clean.json"
jq -e '.tasks | all(.runtime.state != "running")' "$root/tasks-clean.json" >/dev/null
echo "STREAM-CLEANUP-GREEN-83a7"
