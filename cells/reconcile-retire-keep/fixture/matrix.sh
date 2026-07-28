#!/usr/bin/env bash
set -euo pipefail

root="${CATALOG:?CATALOG must be set}"
net="$root/net"
state="$root/state"
exec_state="$state/st2/rc/exec"
export XDG_STATE_HOME="$state"
export PTY_ROOT="$net/pty"

spec_for() {
  printf '%s/agents/rc/%s/agent.kdl\n' "$net" "$1"
}

pid_file() {
  printf '%s/rc.%s.helper.pid\n' "$exec_state" "$1"
}

log_file() {
  printf '%s/logs/rc.%s.helper.log\n' "$net" "$1"
}

retire() {
  spec="$(spec_for "$1")"
  grep -Fq 'retired #true' "$spec" || sed -i '/role "worker"/a\\  retired #true' "$spec"
}

disable_keep() {
  sed -i '/keep #true/d' "$(spec_for "$1")"
}

kill_task() {
  pid="$(cat "$(pid_file "$1")")"
  kill -TERM -- "-$pid"
}

wait_dead() {
  pid="$1"
  for _ in $(seq 1 100); do
    if ! kill -0 "$pid" 2>/dev/null; then
      return 0
    fi
    sleep 0.05
  done
  printf 'pid %s did not stop\n' "$pid" >&2
  return 1
}

wait_file() {
  file="$1"
  for _ in $(seq 1 100); do
    if test -s "$file"; then
      return 0
    fi
    sleep 0.05
  done
  printf 'file %s was not populated\n' "$file" >&2
  return 1
}

wait_count() {
  file="$1"
  expected="$2"
  for _ in $(seq 1 100); do
    if test -s "$file" && test "$(cat "$file")" -eq "$expected"; then
      return 0
    fi
    sleep 0.05
  done
  printf 'file %s did not reach %s\n' "$file" "$expected" >&2
  return 1
}

wait_log() {
  marker="$1"
  file="$2"
  for _ in $(seq 1 100); do
    if grep -Fq "$marker" "$file" 2>/dev/null; then
      return 0
    fi
    sleep 0.05
  done
  printf 'log %s did not contain %s\n' "$file" "$marker" >&2
  return 1
}

cleanup() {
  for label in restart keep retire-live retire-dead; do
    file="$(pid_file "$label")"
    if test -f "$file"; then
      pid="$(cat "$file" 2>/dev/null || true)"
      case "$pid" in
        ''|*[!0-9]*) ;;
        *) kill -TERM -- "-$pid" 2>/dev/null || true ;;
      esac
    fi
    retire "$label" 2>/dev/null || true
    disable_keep "$label" 2>/dev/null || true
  done
  st2 up --once --catalog "$net" --host rc >/dev/null 2>&1 || true
  sleep 0.1
  st2 up --once --catalog "$net" --host rc >/dev/null 2>&1 || true
}
trap cleanup EXIT

st2 up --once --catalog "$net" --host rc >"$root/launch.out"
for label in restart keep retire-live retire-dead; do
  wait_file "$(pid_file "$label")"
  wait_file "$net/$label-count"
  test "$(cat "$net/$label-count")" -eq 1
done
grep -Fq 'launched (4)' "$root/launch.out"

restart_pid1="$(cat "$(pid_file restart)")"
keep_pid="$(cat "$(pid_file keep)")"
retire_live_pid="$(cat "$(pid_file retire-live)")"
retire_dead_pid="$(cat "$(pid_file retire-dead)")"

st2 up --once --catalog "$net" --host rc >"$root/adopt.out"
grep -Fq 'adopted (4)' "$root/adopt.out"
test "$(cat "$(pid_file restart)")" -eq "$restart_pid1"
echo "MISSING-AND-ADOPT-GREEN-52fd"

kill_task restart
kill_task keep
kill_task retire-dead
wait_dead "$restart_pid1"
wait_dead "$keep_pid"
wait_dead "$retire_dead_pid"
retire retire-live
retire retire-dead

st2 up --once --catalog "$net" --host rc >"$root/transition.out"
restart_pid2="$(cat "$(pid_file restart)")"
wait_count "$net/restart-count" 2
wait_log restart-GENERATION-2-52fd "$(log_file restart)"
test "$restart_pid2" -ne "$restart_pid1"
test "$(cat "$net/restart-count")" -eq 2
grep -Fq restart-GENERATION-1-52fd "$(log_file restart).1"
grep -Fq restart-GENERATION-2-52fd "$(log_file restart)"
grep -Fq 'launched (1): rc.restart.helper' "$root/transition.out"
echo "DEAD-NONKEEP-RESTART-GREEN-52fd"

test "$(cat "$(pid_file keep)")" -eq "$keep_pid"
test "$(cat "$net/keep-count")" -eq 1
test -f "$(log_file keep)"
test ! -e "$(log_file keep).1"
grep -Fq 'adopted (1): keep' "$root/transition.out"
echo "DEAD-KEEP-FROZEN-GREEN-52fd"

grep -Fq 'torn down (1): rc.retire-live.helper' "$root/transition.out"
wait_dead "$retire_live_pid"
test -f "$(pid_file retire-live)"
test -f "$(log_file retire-live)"
echo "RETIRED-LIVE-STOPPED-GREEN-52fd"

grep -Eq '^  gc .*rc\.retire-dead\.helper' "$root/transition.out"
test ! -e "$(pid_file retire-dead)"
test ! -e "$(log_file retire-dead)"
echo "RETIRED-DEAD-COLLECTED-GREEN-52fd"

st2 up --once --catalog "$net" --host rc >"$root/retired-final.out"
test -e "$(pid_file retire-live)"
test -e "$(log_file retire-live)"
disable_keep retire-live
st2 up --once --catalog "$net" --host rc >/dev/null
test ! -e "$(pid_file retire-live)"
test ! -e "$(log_file retire-live)"

retire restart
retire keep
disable_keep keep
st2 up --once --catalog "$net" --host rc >/dev/null
wait_dead "$restart_pid2"
st2 up --once --catalog "$net" --host rc >/dev/null
trap - EXIT

test -z "$(find "$exec_state" -maxdepth 1 -type f -name '*.pid' -print -quit 2>/dev/null)"
test -z "$(find "$net/logs" -maxdepth 1 -type f -print -quit 2>/dev/null)"
test "$(PTY_ROOT="$PTY_ROOT" pty list --json | jq 'length')" -eq 0
echo "MATRIX-CLEANUP-GREEN-52fd"
