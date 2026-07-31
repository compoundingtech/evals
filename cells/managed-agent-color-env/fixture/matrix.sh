#!/usr/bin/env bash
set -euo pipefail

root="${CATALOG:?CATALOG must be set}"
net="$root/net"
export XDG_STATE_HOME="$root/state"
export PTY_ROOT="$net/pty"
runtime_dir="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
test -S "$runtime_dir/bus"
export XDG_RUNTIME_DIR="$runtime_dir"
systemd-run --user --scope --quiet true

pty_at() {
  env -u PTY_SESSION PTY_ROOT="$PTY_ROOT" pty "$@"
}

cleanup() {
  for agent in ambient explicit; do
    spec="$net/agents/color/$agent/agent.kdl"
    grep -Fq 'retired #true' "$spec" 2>/dev/null ||
      sed -i "/role \"worker\"/a\\  retired #true" "$spec" 2>/dev/null || true
  done
  NO_COLOR=1 st2 up --once --catalog "$net" --host color >/dev/null 2>&1 || true
  NO_COLOR=1 st2 up --once --catalog "$net" --host color >/dev/null 2>&1 || true
  for id in color.ambient color.explicit; do
    pty_at kill "$id" >/dev/null 2>&1 || true
    pty_at rm "$id" >/dev/null 2>&1 || true
  done
}
trap cleanup EXIT

wait_for_file() {
  path="$1"
  for _ in $(seq 1 100); do
    test -s "$path" && return 0
    sleep 0.05
  done
  printf 'timed out waiting for %s\n' "$path" >&2
  return 1
}

session_pid() {
  pty_at list --json |
    jq -er --arg id "$1" '.[] | select(.name == $id and .status == "running") | .pid'
}

in_st2_scope() {
  pid="$(session_pid "$1")"
  grep -Eq "st2-${1//./\\.}-[0-9]+-[0-9]+\\.scope" "/proc/$pid/cgroup"
}

NO_COLOR=1 st2 up --once --catalog "$net" --host color >/dev/null
wait_for_file "$net/observed/ambient.1"
wait_for_file "$net/observed/explicit.1"

grep -Fqx 'NO_COLOR=<unset>' "$net/observed/ambient.1"
grep -Fqx 'TERM=xterm-256color' "$net/observed/ambient.1"
echo "AMBIENT-COLOR-DEFAULT-GREEN-90c4"

grep -Fqx 'NO_COLOR=1' "$net/observed/explicit.1"
grep -Fqx 'TERM=xterm-256color' "$net/observed/explicit.1"
echo "EXPLICIT-NO-COLOR-GREEN-90c4"

ambient_pid_1="$(session_pid color.ambient)"
explicit_pid_1="$(session_pid color.explicit)"
in_st2_scope color.ambient
in_st2_scope color.explicit
echo "SYSTEMD-SCOPE-GREEN-90c4"
NO_COLOR=1 st2 up --once --catalog "$net" --host color >/dev/null
test "$(session_pid color.ambient)" -eq "$ambient_pid_1"
test "$(session_pid color.explicit)" -eq "$explicit_pid_1"
test "$(cat "$net/observed/ambient.count")" -eq 1
test "$(cat "$net/observed/explicit.count")" -eq 1
echo "LIVE-ADOPTION-GREEN-90c4"

pty_at kill color.ambient >/dev/null
pty_at kill color.explicit >/dev/null
NO_COLOR=1 st2 up --once --catalog "$net" --host color >/dev/null
wait_for_file "$net/observed/ambient.2"
wait_for_file "$net/observed/explicit.2"

grep -Fqx 'NO_COLOR=<unset>' "$net/observed/ambient.2"
grep -Fqx 'TERM=xterm-256color' "$net/observed/ambient.2"
grep -Fqx 'NO_COLOR=1' "$net/observed/explicit.2"
grep -Fqx 'TERM=xterm-256color' "$net/observed/explicit.2"
test "$(session_pid color.ambient)" -ne "$ambient_pid_1"
test "$(session_pid color.explicit)" -ne "$explicit_pid_1"
in_st2_scope color.ambient
in_st2_scope color.explicit
echo "REPLACEMENT-POLICY-GREEN-90c4"

printf '\034' | NO_COLOR=1 env -u PTY_SESSION PTY_ROOT="$PTY_ROOT" \
  pty restart -y --force color.ambient >"$root/ambient-restart.out" 2>"$root/ambient-restart.err"
wait_for_file "$net/observed/ambient.3"
grep -Fqx 'NO_COLOR=<unset>' "$net/observed/ambient.3"
grep -Fqx 'TERM=xterm-256color' "$net/observed/ambient.3"

printf '\034' | env -u NO_COLOR -u PTY_SESSION PTY_ROOT="$PTY_ROOT" \
  pty restart -y --force color.explicit >"$root/explicit-restart.out" 2>"$root/explicit-restart.err"
wait_for_file "$net/observed/explicit.3"
grep -Fqx 'NO_COLOR=1' "$net/observed/explicit.3"
grep -Fqx 'TERM=xterm-256color' "$net/observed/explicit.3"
echo "PTY-RESTART-POLICY-GREEN-90c4"

for agent in ambient explicit; do
  sed -i "/role \"worker\"/a\\  retired #true" "$net/agents/color/$agent/agent.kdl"
done
NO_COLOR=1 st2 up --once --catalog "$net" --host color >/dev/null
NO_COLOR=1 st2 up --once --catalog "$net" --host color >/dev/null
trap - EXIT
test "$(pty_at list --json | jq 'length')" -eq 0
echo "COLOR-MATRIX-CLEANUP-GREEN-90c4"
