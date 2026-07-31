#!/usr/bin/env bash
set -euo pipefail

root="${CATALOG:?CATALOG must be set}"
pty_root="$root/machine-pty"
remote_socket="$root/remote.sock"
proxy_socket="$root/proxy.sock"
stream="$root/attach.stream"
stdout="$root/attach.stdout"
stderr="$root/attach.stderr"
attach_pid=""
remote_pid=""
proxy_pid=""
small_pid=""
export PTY_ROOT="$pty_root"

pty_at() {
  env -u PTY_SESSION PTY_ROOT="$PTY_ROOT" pty "$@"
}

cleanup() {
  if test -n "$attach_pid"; then
    kill "$attach_pid" >/dev/null 2>&1 || true
    wait "$attach_pid" >/dev/null 2>&1 || true
  fi
  for pid in "$small_pid" "$proxy_pid" "$remote_pid"; do
    if test -n "$pid"; then
      kill "$pid" >/dev/null 2>&1 || true
      wait "$pid" >/dev/null 2>&1 || true
    fi
  done
  pty_at kill ms.target >/dev/null 2>&1 || true
  pty_at rm ms.target >/dev/null 2>&1 || true
}
trap cleanup EXIT

wait_for() {
  description="$1"
  shift
  for _ in $(seq 1 200); do
    if "$@"; then
      return 0
    fi
    sleep 0.05
  done
  printf 'timed out waiting for %s\n' "$description" >&2
  return 1
}

session_running() {
  pty_at list --json |
    jq -e --arg id "$1" '.[] | select(.name == $id and .status == "running")' >/dev/null
}

peek_has() {
  pty_at peek --plain ms.target 2>/dev/null | grep -Fq "$1"
}

pty_at run -d --id ms.target --no-display-name -- bash "$root/target.sh"
wait_for "target output" peek_has INITIAL_COLOR_61e8

env -u PTY_SESSION PTY_ROOT="$PTY_ROOT" \
  pty remote-serve --socket "$remote_socket" >"$root/remote.log" 2>&1 &
remote_pid="$!"
wait_for "remote socket" test -S "$remote_socket"

node "$root/drop-proxy.mjs" "$proxy_socket" "$remote_socket" "$root/drop-first" \
  >"$root/proxy.log" 2>&1 &
proxy_pid="$!"
wait_for "proxy socket" test -S "$proxy_socket"

PTY_EVAL_STATE="$root/fabric-state" \
PTY_EVAL_SOCKET_1="$proxy_socket" \
PTY_EVAL_SOCKET_2="$remote_socket" \
PTY_FABRIC_BIN="$root/fabric" \
env -u PTY_SESSION PTY_ROOT="$PTY_ROOT" \
  pty attach --remote eval-peer --attach-stream-fd-v1 3 ms.target \
  3>"$stream" >"$stdout" 2>"$stderr" &
attach_pid="$!"

wait_for "initial machine snapshot" node "$root/check-stream.mjs" "$stream" snapshots 1 24x80,13x47
touch "$root/drop-first"
wait_for "second fabric dial" test -f "$root/fabric-state/second-dial"

pty_at send ms.target --seq AFTER_DROP_61e8 --seq key:return
wait_for "post-drop target output" peek_has AFTER_DROP_61e8
env -u PTY_SESSION PTY_ROOT="$PTY_ROOT" \
  script -qefc 'stty rows 13 cols 47; exec pty attach --no-restart ms.target' /dev/null \
  >"$root/small.stdout" 2>"$root/small.stderr" &
small_pid="$!"
wait_for "smaller attached client" grep -Fq INITIAL_COLOR_61e8 "$root/small.stdout"
touch "$root/fabric-state/release-second"

wait_for "reconnect machine snapshot" node "$root/check-stream.mjs" "$stream" snapshots 2 24x80,13x47
pty_at send ms.target --seq EXIT_61e8 --seq key:return

wait_for "attach process exit" sh -c "! kill -0 '$attach_pid' 2>/dev/null"
if wait "$attach_pid"; then
  attach_status=0
else
  attach_status="$?"
  printf 'machine attach exited %s\n' "$attach_status" >&2
  sed -n '1,120p' "$stderr" >&2
  exit "$attach_status"
fi
attach_pid=""

node "$root/check-stream.mjs" "$stream" final 2 24x80,13x47 "$stdout" "$stderr" > "$root/stream-proof"
grep -Fqx PACKAGED-FD-GREEN-61e8 "$root/stream-proof"
grep -Fqx INITIAL-SNAPSHOT-GREEN-61e8 "$root/stream-proof"
grep -Fqx RECONNECT-SNAPSHOT-GREEN-61e8 "$root/stream-proof"
grep -Fqx FRAMED-TERMINAL-STREAM-GREEN-61e8 "$root/stream-proof"
cat "$root/stream-proof"

for pid in "$small_pid" "$proxy_pid" "$remote_pid"; do
  kill "$pid" >/dev/null 2>&1 || true
  wait "$pid" >/dev/null 2>&1 || true
done
small_pid=""
proxy_pid=""
remote_pid=""
pty_at kill ms.target >/dev/null 2>&1 || true
pty_at rm ms.target >/dev/null 2>&1 || true
trap - EXIT
test "$(pty_at list --json | jq 'length')" -eq 0
echo "MACHINE-STREAM-CLEANUP-GREEN-61e8"
