#!/usr/bin/env bash
set -euo pipefail

root="${CATALOG:?CATALOG must be set}"
net="$root/net"
state="$root/state"
export XDG_STATE_HOME="$state"
export PTY_ROOT="$net/pty"

tasks() {
  st2 tasks --catalog "$net" --host proof --json
}

wait_task_state() {
  runtime_id="$1"
  expected="$2"
  for _ in $(seq 1 100); do
    observed="$(tasks | jq -r --arg id "$runtime_id" '.tasks[] | select(.runtimeId == $id) | .runtime.state')"
    if test "$observed" = "$expected"; then
      return 0
    fi
    sleep 0.05
  done
  printf '%s did not reach %s\n' "$runtime_id" "$expected" >&2
  return 1
}

cleanup() {
  st2 down --catalog "$net" --host proof >/dev/null 2>&1 || true
  for identity in worker sibling; do
    st2 agent desired-state --catalog "$net" "$identity" retired \
      --reason "Eval cleanup" --host proof >/dev/null 2>&1 || true
  done
  for _ in $(seq 1 100); do
    st2 up --once --catalog "$net" --host proof >/dev/null 2>&1 || true
    if tasks 2>/dev/null | jq -e 'all(.tasks[]; .runtime.state == "absent")' >/dev/null; then
      break
    fi
    sleep 0.05
  done
}
trap cleanup EXIT

st2 up --once --catalog "$net" --host proof >"$root/launch.out"
grep -Fq 'launched (3)' "$root/launch.out"
initial="$(tasks)"
sibling_pid="$(jq -r '.tasks[] | select(.runtimeId == "proof.sibling") | .runtime.pid' <<<"$initial")"
sibling_generation="$(jq -r '.tasks[] | select(.runtimeId == "proof.sibling") | .runtime.generationId' <<<"$initial")"
test "$sibling_pid" != null
test "$sibling_generation" != null

message="$(st2 message send --catalog "$net" worker --as proof.sibling --host proof \
  --subject retained -m "survive suspension")"
test -f "$net/agents/proof/worker/resources/inbox/$message"

st2 agent desired-state --catalog "$net" worker suspended \
  --reason "Waiting for capacity" --host proof --json >"$root/suspend-author.json"
jq -e '.result == "changed" and .desired_state == "suspended" and .reason == "Waiting for capacity"' \
  "$root/suspend-author.json" >/dev/null
st2 up --once --catalog "$net" --host proof >"$root/suspend.out"
grep -Fq 'torn down (2): proof.worker, proof.worker.ding' "$root/suspend.out"
grep -Fq 'adopted (1): sibling' "$root/suspend.out"
: >"$root/suspend-settle.out"
for _ in $(seq 1 100); do
  st2 up --once --catalog "$net" --host proof >>"$root/suspend-settle.out"
  settled="$(tasks)"
  if test "$(jq -r '.tasks[] | select(.runtimeId == "proof.worker") | .runtime.state' <<<"$settled")" = absent \
    && test "$(jq -r '.tasks[] | select(.runtimeId == "proof.worker.ding") | .runtime.state' <<<"$settled")" = absent; then
    break
  fi
  sleep 0.05
done
grep -Fq 'adopted (1): sibling' "$root/suspend-settle.out"
wait_task_state proof.worker absent
wait_task_state proof.worker.ding absent
suspended="$(tasks)"
test "$(jq -r '.tasks[] | select(.runtimeId == "proof.sibling") | .runtime.pid' <<<"$suspended")" = "$sibling_pid"
test "$(jq -r '.tasks[] | select(.runtimeId == "proof.sibling") | .runtime.generationId' <<<"$suspended")" = "$sibling_generation"
echo SUSPEND-GREEN-7c31

test -f "$net/agents/proof/worker/resources/inbox/$message"
st2 message ls --catalog "$net" worker --as proof.sibling --host proof --json \
  | jq -e --arg filename "$message" 'any(.[]; .filename == $filename)' >/dev/null
echo INBOX-RETAINED-GREEN-7c31

jq -e '.tasks[] | select(.runtimeId == "proof.worker")
  | .desiredState == "absent"
    and .agentDesiredState == "suspended"
    and .agentDesiredStateReason == "Waiting for capacity"
    and .retired == false' <<<"$suspended" >/dev/null
st2 agents --catalog "$net" --host proof --json \
  | jq -e '.[] | select(.identity == "proof.worker")
    | .desiredState == "suspended"
      and .desiredStateReason == "Waiting for capacity"
      and .retired == false' >/dev/null
echo OBSERVABILITY-GREEN-7c31

st2 agent desired-state --catalog "$net" worker running --host proof --json >"$root/resume-author.json"
jq -e '.result == "changed" and .desired_state == "running" and .reason == null' \
  "$root/resume-author.json" >/dev/null
st2 up --once --catalog "$net" --host proof >"$root/resume.out"
grep -Fq 'launched (2): proof.worker, proof.worker.ding' "$root/resume.out"
grep -Fq 'adopted (1): sibling' "$root/resume.out"
wait_task_state proof.worker running
wait_task_state proof.worker.ding running
resumed="$(tasks)"
test "$(jq -r '.tasks[] | select(.runtimeId == "proof.sibling") | .runtime.pid' <<<"$resumed")" = "$sibling_pid"
test "$(jq -r '.tasks[] | select(.runtimeId == "proof.sibling") | .runtime.generationId' <<<"$resumed")" = "$sibling_generation"
test -f "$net/agents/proof/worker/resources/inbox/$message"
echo RESUME-GREEN-7c31

cleanup
trap - EXIT
test "$(PTY_ROOT="$PTY_ROOT" pty list --json | jq 'length')" -eq 0
if test -d "$state/st2/proof/exec"; then
  test -z "$(find "$state/st2/proof/exec" -maxdepth 1 -type f -name '*.pid' -print -quit)"
fi
echo CLEANUP-GREEN-7c31
