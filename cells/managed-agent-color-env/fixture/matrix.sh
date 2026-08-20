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

expected_st2_commit="389eeb8"
expected_st2_sha256="f3dbd6901f59decdea999de08c6ddc72683a36d79ad4cf5cb219b554c63c8ba9"
expected_pty_sha256="1c9716d435ca56ad9b4f67056d76fa6856cdc08e6bbda1fd4be6f59952e9fde3"
st2_path="$(command -v st2)"
pty_path="$(command -v pty)"
case "$(st2 --version)" in
  *"($expected_st2_commit,"*) ;;
  *) printf 'unexpected st2 identity: %s\n' "$(st2 --version)" >&2; exit 1 ;;
esac
test "$(sha256sum "$st2_path" | awk '{ print $1 }')" = "$expected_st2_sha256"
test "$(sha256sum "$pty_path" | awk '{ print $1 }')" = "$expected_pty_sha256"
echo "EXACT-RUNTIME-PROVENANCE-GREEN-90c4"

process_identities=()
scope_units=()
scope_cgroups=()

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

process_start_time() {
  sed -E 's/^[0-9]+ \(.*\) //' "/proc/$1/stat" | awk '{ print $20 }'
}

record_process() {
  pid="$1"
  process_identities+=("$pid:$(process_start_time "$pid")")
}

in_st2_scope() {
  pid="$(session_pid "$1")"
  scope="$(sed -nE "s#.*(st2-${1//./\\.}-[0-9]+-[0-9]+\\.scope).*#\\1#p" "/proc/$pid/cgroup")"
  test -n "$scope"
  cgroup="$(awk -F: '$1 == "0" { print $3 }' "/proc/$pid/cgroup")"
  test -n "$cgroup"
  scope_units+=("$scope")
  scope_cgroups+=("$cgroup")
}

assert_cleanup() {
  test "$(pty_at list --json | jq 'length')" -eq 0
  for identity in "${process_identities[@]}"; do
    pid="${identity%%:*}"
    expected_start="${identity#*:}"
    if test -r "/proc/$pid/stat" && test "$(process_start_time "$pid")" = "$expected_start"; then
      printf 'eval-owned process remains alive: pid=%s start=%s\n' "$pid" "$expected_start" >&2
      return 1
    fi
  done
  for scope in "${scope_units[@]}"; do
    if systemctl --user is-active --quiet "$scope"; then
      printf 'eval-owned scope remains active: %s\n' "$scope" >&2
      return 1
    fi
  done
  for cgroup in "${scope_cgroups[@]}"; do
    if test -e "/sys/fs/cgroup$cgroup"; then
      printf 'eval-owned scope cgroup remains: %s\n' "$cgroup" >&2
      return 1
    fi
  done
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
record_process "$ambient_pid_1"
record_process "$explicit_pid_1"
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
record_process "$(session_pid color.ambient)"
record_process "$(session_pid color.explicit)"
in_st2_scope color.ambient
in_st2_scope color.explicit
echo "REPLACEMENT-POLICY-GREEN-90c4"

printf '\034' | NO_COLOR=1 env -u PTY_SESSION PTY_ROOT="$PTY_ROOT" \
  pty restart -y --force color.ambient >"$root/ambient-restart.out" 2>"$root/ambient-restart.err"
wait_for_file "$net/observed/ambient.3"
grep -Fqx 'NO_COLOR=<unset>' "$net/observed/ambient.3"
grep -Fqx 'TERM=xterm-256color' "$net/observed/ambient.3"
record_process "$(session_pid color.ambient)"

printf '\034' | env -u NO_COLOR -u PTY_SESSION PTY_ROOT="$PTY_ROOT" \
  pty restart -y --force color.explicit >"$root/explicit-restart.out" 2>"$root/explicit-restart.err"
wait_for_file "$net/observed/explicit.3"
grep -Fqx 'NO_COLOR=1' "$net/observed/explicit.3"
grep -Fqx 'TERM=xterm-256color' "$net/observed/explicit.3"
record_process "$(session_pid color.explicit)"
echo "PTY-RESTART-POLICY-GREEN-90c4"

for agent in ambient explicit; do
  sed -i "/role \"worker\"/a\\  retired #true" "$net/agents/color/$agent/agent.kdl"
done
NO_COLOR=1 st2 up --once --catalog "$net" --host color >/dev/null
NO_COLOR=1 st2 up --once --catalog "$net" --host color >/dev/null
assert_cleanup
echo "COLOR-MATRIX-CLEANUP-GREEN-90c4"
trap - EXIT
