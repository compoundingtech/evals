#!/usr/bin/env bash
set -euo pipefail

root="${CATALOG:?CATALOG must be set}"
net="$root/net"
state="$root/state"
exec_state="$state/st2/ex/exec"
id="ex.agent.helper"
pid_file="$exec_state/$id.pid"
current="$net/logs/$id.log"
previous="$current.1"
export XDG_STATE_HOME="$state"
export PTY_ROOT="$net/pty"

cleanup() {
  st2 down --catalog "$net" --host ex >/dev/null 2>&1 || true
  if test -f "$pid_file"; then
    pid="$(cat "$pid_file" 2>/dev/null || true)"
    case "$pid" in
      ''|*[!0-9]*) ;;
      *) kill -TERM -- "-$pid" 2>/dev/null || true ;;
    esac
  fi
  spec="$net/agents/ex/agent/agent.kdl"
  grep -Fq 'retired #true' "$spec" 2>/dev/null ||
    sed -i '/role "worker"/a\\  retired #true' "$spec" 2>/dev/null || true
  st2 up --once --catalog "$net" --host ex >/dev/null 2>&1 || true
}
trap cleanup EXIT

wait_for() {
  description="$1"
  shift
  for _ in $(seq 1 100); do
    if "$@"; then
      return 0
    fi
    sleep 0.05
  done
  printf 'timed out waiting for %s\n' "$description" >&2
  return 1
}

log_has() {
  grep -Fq "$1" "$2" 2>/dev/null
}

st2 up --once --catalog "$net" --host ex >/dev/null
wait_for "first pid" test -s "$pid_file"
pid1="$(cat "$pid_file")"
wait_for "first child" test -s "$net/generation-child-1"
child1="$(cat "$net/generation-child-1")"
wait_for "first log" log_has GENERATION_1_ERR_c81a "$current"

stat="$(cat "/proc/$pid1/stat")"
after="${stat##*) }"
set -- $after
pgrp="$3"
session="$4"
tty_nr="$5"
test "$pgrp" -eq "$pid1"
test "$session" -eq "$pid1"
test "$tty_nr" -eq 0
test "$(cat "$net/generation-count")" -eq 1
test "$(PTY_ROOT="$PTY_ROOT" pty list --json | jq '[.[] | select(.name == "ex.agent.helper")] | length')" -eq 0
echo "TERMINAL-FREE-DETACHED-GREEN-c81a"

if test -n "${XDG_RUNTIME_DIR:-}" && systemd-run --user --version >/dev/null 2>&1; then
  grep -Eq 'st2-ex\.agent\.helper-.*\.scope' "/proc/$pid1/cgroup"
  echo "ISOLATION-SCOPE-GREEN-c81a"
else
  echo "ISOLATION-DETACHED-GREEN-c81a"
fi

st2 up --once --catalog "$net" --host ex >/dev/null
test "$(cat "$pid_file")" -eq "$pid1"
test "$(cat "$net/generation-count")" -eq 1
echo "LIVE-ADOPTION-GREEN-c81a"

kill -TERM -- "-$pid1"
st2 up --once --catalog "$net" --host ex >/dev/null
wait_for "second generation" log_has GENERATION_2_OUT_c81a "$current"
pid2="$(cat "$pid_file")"
child2="$(cat "$net/generation-child-2")"
test "$pid2" -ne "$pid1"
grep -Fq GENERATION_1_OUT_c81a "$previous"

kill -TERM -- "-$pid2"
st2 up --once --catalog "$net" --host ex >/dev/null
wait_for "third generation" log_has GENERATION_3_OUT_c81a "$current"
pid3="$(cat "$pid_file")"
child3="$(cat "$net/generation-child-3")"
test "$pid3" -ne "$pid2"
grep -Fq GENERATION_2_ERR_c81a "$previous"
! grep -Fq GENERATION_1_OUT_c81a "$current" "$previous"
test "$(find "$net/logs" -maxdepth 1 -type f -name "$id.log*" | wc -l)" -eq 2
echo "BOUNDED-LOG-ROTATION-GREEN-c81a"

st2 down --catalog "$net" --host ex >/dev/null
for pid in "$pid1" "$child1" "$pid2" "$child2" "$pid3" "$child3"; do
  wait_for "pid $pid teardown" sh -c "! kill -0 '$pid' 2>/dev/null"
done
sed -i '/role "worker"/a\\  retired #true' "$net/agents/ex/agent/agent.kdl"
st2 up --once --catalog "$net" --host ex >/dev/null
trap - EXIT
test ! -e "$pid_file"
test ! -e "$current"
test ! -e "$previous"
test "$(PTY_ROOT="$PTY_ROOT" pty list --json | jq 'length')" -eq 0
echo "WHOLE-GROUP-TEARDOWN-GREEN-c81a"
