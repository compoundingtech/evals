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

proc_start_token() {
  pid="$1"
  stat="$(<"/proc/$pid/stat")"
  suffix="${stat##*) }"
  read -r -a fields <<<"$suffix"
  printf '%s\n' "${fields[19]}"
}

assert_process_gone() {
  pid="$1"
  start_token="$2"
  label="$3"
  if test -r "/proc/$pid/stat" && test "$(proc_start_token "$pid")" = "$start_token"; then
    printf '%s process identity remains live: pid=%s start=%s\n' "$label" "$pid" "$start_token" >&2
    return 1
  fi
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
worker_pid="$(jq -r '.tasks[] | select(.runtimeId == "proof.worker") | .runtime.pid' <<<"$initial")"
ding_pid="$(jq -r '.tasks[] | select(.runtimeId == "proof.worker.ding") | .runtime.pid' <<<"$initial")"
sibling_pid="$(jq -r '.tasks[] | select(.runtimeId == "proof.sibling") | .runtime.pid' <<<"$initial")"
sibling_generation="$(jq -r '.tasks[] | select(.runtimeId == "proof.sibling") | .runtime.generationId' <<<"$initial")"
test "$worker_pid" != null
test "$ding_pid" != null
test "$sibling_pid" != null
test "$sibling_generation" != null
worker_start_token="$(proc_start_token "$worker_pid")"
ding_start_token="$(proc_start_token "$ding_pid")"

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
assert_process_gone "$worker_pid" "$worker_start_token" proof.worker
assert_process_gone "$ding_pid" "$ding_start_token" proof.worker.ding
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
resumed_worker_pid="$(jq -r '.tasks[] | select(.runtimeId == "proof.worker") | .runtime.pid' <<<"$resumed")"
resumed_ding_pid="$(jq -r '.tasks[] | select(.runtimeId == "proof.worker.ding") | .runtime.pid' <<<"$resumed")"
resumed_sibling_pid="$(jq -r '.tasks[] | select(.runtimeId == "proof.sibling") | .runtime.pid' <<<"$resumed")"
resumed_worker_start_token="$(proc_start_token "$resumed_worker_pid")"
resumed_ding_start_token="$(proc_start_token "$resumed_ding_pid")"
resumed_sibling_start_token="$(proc_start_token "$resumed_sibling_pid")"
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
assert_process_gone "$resumed_worker_pid" "$resumed_worker_start_token" proof.worker
assert_process_gone "$resumed_ding_pid" "$resumed_ding_start_token" proof.worker.ding
assert_process_gone "$resumed_sibling_pid" "$resumed_sibling_start_token" proof.sibling
echo CLEANUP-GREEN-7c31
