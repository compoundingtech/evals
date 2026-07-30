#!/usr/bin/env bash
set -euo pipefail

root="${CATALOG:?CATALOG must be set}/pty-live-recovery-root"
candidate="live-recovery-candidate"
unsupported="live-recovery-unsupported"
candidate_marker="$CATALOG/live-recovery-candidate-runs"
unsupported_marker="$CATALOG/live-recovery-unsupported-runs"
candidate_snapshot="$CATALOG/live-recovery-candidate.snapshot"
unsupported_snapshot="$CATALOG/live-recovery-unsupported.snapshot"
follower_transcript="$CATALOG/live-recovery-follower.transcript"
unsupported_stderr="$CATALOG/live-recovery-unsupported.stderr"
live_command="$PWD/live.sh"
daemon_pids=()
client_pids=()

mkdir -p "$root"

pty_at() {
  PTY_ROOT="$root" env -u PTY_SESSION -u PTY_SESSION_DIR pty "$@"
}

wait_dead() {
  pid="$1"
  for _ in $(seq 1 100); do
    kill -0 "$pid" 2>/dev/null || return 0
    sleep 0.05
  done
  return 1
}

cleanup() {
  for pid in "${client_pids[@]}"; do
    kill "$pid" 2>/dev/null || true
  done
  for pid in "${daemon_pids[@]}"; do
    kill -TERM "$pid" 2>/dev/null || true
  done
  for pid in "${daemon_pids[@]}"; do
    wait_dead "$pid" || true
  done
  rm -rf -- "$root"
}
trap cleanup EXIT

wait_running() {
  id="$1"
  for _ in $(seq 1 100); do
    status="$(
      pty_at list --json |
        jq -r --arg id "$id" '.[] | select(.name == $id) | .status'
    )"
    test "$status" = "running" && return 0
    sleep 0.05
  done
  printf 'timed out waiting for %s (last status: %s)\n' "$id" "${status:-missing}" >&2
  return 1
}

wait_text() {
  file="$1"
  text="$2"
  for _ in $(seq 1 100); do
    test -f "$file" && grep -Fq "$text" "$file" && return 0
    sleep 0.05
  done
  printf 'timed out waiting for %s in %s\n' "$text" "$file" >&2
  return 1
}

wait_peek() {
  id="$1"
  text="$2"
  for _ in $(seq 1 100); do
    pty_at peek --plain "$id" 2>/dev/null | grep -Fq "$text" && return 0
    sleep 0.05
  done
  printf 'timed out waiting for %s from %s\n' "$text" "$id" >&2
  return 1
}

start_count() {
  id="$1"
  jq -s '[.[] | select(.type == "session_start")] | length' "$root/$id.events.jsonl"
}

run_count() {
  wc -l <"$1"
}

unlink_registry() {
  id="$1"
  rm "$root/$id.sock" "$root/$id.pid" "$root/$id.json"
}

if pty recover-live --help |
  grep -Fq 'pty recover-live --metadata <snapshot.json>'; then
  echo "LIVE-RECOVERY-SURFACE-GREEN-c24d"
else
  echo "recover-live snapshot surface is not advertised" >&2
fi

pty_at run -d --id "$candidate" --tag keep=true -- \
  bash "$live_command" "$candidate_marker"
wait_running "$candidate"
wait_peek "$candidate" LIVE-RECOVERY-READY
cp "$root/$candidate.json" "$candidate_snapshot"
candidate_pid="$(jq -er '.daemonPid' "$candidate_snapshot")"
candidate_generation="$(jq -er '.generation' "$candidate_snapshot")"
candidate_start="$(jq -er '.daemonStartToken' "$candidate_snapshot")"
test "$(jq -er '.recoveryProtocol' "$candidate_snapshot")" -eq 1
daemon_pids+=("$candidate_pid")

pty_at peek -f --plain "$candidate" >"$follower_transcript" 2>&1 &
follower_pid=$!
client_pids+=("$follower_pid")
wait_text "$follower_transcript" LIVE-RECOVERY-READY

unlink_registry "$candidate"
kill -0 "$candidate_pid"
pty_at recover-live --metadata "$candidate_snapshot" "$candidate"

test "$(cat "$root/$candidate.pid")" -eq "$candidate_pid"
test "$(jq -er '.daemonPid' "$root/$candidate.json")" -eq "$candidate_pid"
test "$(jq -er '.generation' "$root/$candidate.json")" = "$candidate_generation"
test "$(jq -er '.daemonStartToken' "$root/$candidate.json")" = "$candidate_start"
kill -0 "$candidate_pid"
echo "LIVE-RECOVERY-IDENTITY-GREEN-c24d"

kill -0 "$follower_pid"
pty_at send "$candidate" --seq post-rebind --seq key:return
wait_text "$follower_transcript" LIVE-RECOVERY-ACK:post-rebind
kill -0 "$follower_pid"
echo "LIVE-RECOVERY-CONTINUITY-GREEN-c24d"

pty_at peek --plain "$candidate" | grep -Fq LIVE-RECOVERY-ACK:post-rebind
echo "LIVE-RECOVERY-NEW-CLIENT-GREEN-c24d"

test "$(run_count "$candidate_marker")" -eq 1
test "$(start_count "$candidate")" -eq 1
echo "LIVE-RECOVERY-NO-DUPLICATE-GREEN-c24d"

pty_at run -d --id "$unsupported" --tag keep=true -- \
  bash "$live_command" "$unsupported_marker"
wait_running "$unsupported"
jq 'del(.recoveryProtocol, .daemonStartToken)' \
  "$root/$unsupported.json" >"$unsupported_snapshot"
unsupported_pid="$(jq -er '.daemonPid' "$unsupported_snapshot")"
daemon_pids+=("$unsupported_pid")
unlink_registry "$unsupported"

set +e
pty_at recover-live --metadata "$unsupported_snapshot" "$unsupported" \
  >/dev/null 2>"$unsupported_stderr"
unsupported_rc=$?
set -e
test "$unsupported_rc" -ne 0
grep -Fq 'refusing recovery' "$unsupported_stderr"
kill -0 "$unsupported_pid"
test "$(run_count "$unsupported_marker")" -eq 1
echo "LIVE-RECOVERY-UNSUPPORTED-REFUSAL-GREEN-c24d"

cleanup
trap - EXIT
test ! -e "$root"
echo "LIVE-RECOVERY-CLEANUP-GREEN-c24d"
