#!/usr/bin/env bash
set -euo pipefail

root="${CATALOG:?CATALOG must be set}/attach-only-pty"
candidate="attach-only-dead"
control="legacy-dead"
live="attach-only-live"
candidate_marker="$CATALOG/attach-only-runs"
control_marker="$CATALOG/legacy-runs"
live_marker="$CATALOG/live-runs"
candidate_transcript_no_input="$CATALOG/attach-only-no-input.transcript"
candidate_transcript_future="$CATALOG/attach-only-future.transcript"
control_transcript="$CATALOG/legacy.transcript"
live_transcript="$CATALOG/live.transcript"
once="$PWD/once.sh"
live_command="$PWD/live.sh"

mkdir -p "$root"

pty_at() {
  PTY_ROOT="$root" env -u PTY_SESSION pty "$@"
}

cleanup() {
  for id in "$candidate" "$control" "$live"; do
    pty_at kill "$id" >/dev/null 2>&1 || true
    pty_at rm "$id" >/dev/null 2>&1 || true
  done
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
  printf 'timed out waiting for %s to run (last status: %s)\n' "$id" "${status:-missing}" >&2
  return 1
}

wait_exited() {
  id="$1"
  for _ in $(seq 1 100); do
    status="$(
      pty_at list --json |
        jq -r --arg id "$id" '.[] | select(.name == $id) | .status'
    )"
    test "$status" = "exited" && return 0
    sleep 0.05
  done
  printf 'timed out waiting for %s to exit (last status: %s)\n' "$id" "${status:-missing}" >&2
  return 1
}

run_count() {
  marker="$1"
  test -f "$marker" || {
    printf '0\n'
    return
  }
  wc -l <"$marker"
}

start_count() {
  id="$1"
  jq -s '[.[] | select(.type == "session_start")] | length' "$root/$id.events.jsonl"
}

pid_is_candidate_daemon() {
  pid="$1"
  test -r "/proc/$pid/environ" || return 1
  tr '\0' '\n' <"/proc/$pid/environ" | grep -Fxq "PTY_ROOT=$root" &&
    tr '\0' ' ' <"/proc/$pid/cmdline" | grep -Fq "$candidate"
}

if pty attach --help | grep -Eq '(^|[[:space:]])--no-restart([[:space:]]|$)'; then
  echo "ATTACH-ONLY-SURFACE-GREEN-7ca1"
else
  echo "attach --no-restart is not advertised" >&2
fi

pty_at run -d --id "$live" --tag keep=true -- bash "$live_command" "$live_marker"
wait_running "$live"
for _ in $(seq 1 100); do
  pty_at peek --plain "$live" 2>/dev/null | grep -Fq ATTACH-ONLY-LIVE-READY && break
  sleep 0.05
done
pty_at peek --plain "$live" | grep -Fq ATTACH-ONLY-LIVE-READY
set +e
printf 'live-input\n' |
  timeout 10 script -qefc \
    "env -u PTY_SESSION PTY_ROOT='$root' pty attach --no-restart '$live'" \
    /dev/null >"$live_transcript" 2>&1
live_rc=$?
set -e
test "$live_rc" -eq 37
grep -Fq ATTACH-ONLY-LIVE-READY "$live_transcript"
grep -Fq LIVE-ACK:live-input "$live_transcript"
wait_exited "$live"
test "$(run_count "$live_marker")" -eq 1
test "$(start_count "$live")" -eq 1
echo "LIVE-ATTACH-ROUNDTRIP-GREEN-7ca1"

pty_at run -d --id "$control" --tag keep=true -- bash "$once" "$control_marker"
wait_exited "$control"
test "$(run_count "$control_marker")" -eq 1

# A real terminal and queued future input make the legacy failure deterministic:
# anything except exactly "n" answers the dead-session restart prompt affirmatively.
set +e
printf 'future-input\n' |
  timeout 10 script -qefc \
    "env -u PTY_SESSION PTY_ROOT='$root' pty attach '$control'" \
    /dev/null >"$control_transcript" 2>&1
control_rc=$?
set -e

wait_exited "$control"
test "$control_rc" -ne 124
grep -Fq 'Restart? [Y/n]' "$control_transcript"
test "$(run_count "$control_marker")" -eq 2
echo "LEGACY-RESTART-CONTROL-GREEN-7ca1"

pty_at run -d --id "$candidate" --tag keep=true -- bash "$once" "$candidate_marker"
wait_exited "$candidate"
test "$(run_count "$candidate_marker")" -eq 1
test "$(start_count "$candidate")" -eq 1
before_pid="$(
  pty_at list --json |
    jq -er --arg id "$candidate" '.[] | select(.name == $id and .status == "exited") | .pid'
)"
! pid_is_candidate_daemon "$before_pid"

set +e
timeout 10 script -qefc \
  "env -u PTY_SESSION PTY_ROOT='$root' pty attach --no-restart '$candidate'" \
  /dev/null </dev/null >"$candidate_transcript_no_input" 2>&1
candidate_rc_no_input=$?
printf 'future-input\n' |
  timeout 10 script -qefc \
    "env -u PTY_SESSION PTY_ROOT='$root' pty attach --no-restart '$candidate'" \
    /dev/null >"$candidate_transcript_future" 2>&1
candidate_rc_future=$?
set -e

test "$candidate_rc_no_input" -ne 0
test "$candidate_rc_no_input" -ne 124
test "$candidate_rc_future" -ne 0
test "$candidate_rc_future" -ne 124
tr -d '\r' <"$candidate_transcript_no_input" >"$candidate_transcript_no_input.normalized"
tr -d '\r' <"$candidate_transcript_future" >"$candidate_transcript_future.normalized"
expected_diagnostic="Session \"$candidate\" is not running (status: exited)."
grep -Fqx "$expected_diagnostic" "$candidate_transcript_no_input.normalized"
grep -Fqx "$expected_diagnostic" "$candidate_transcript_future.normalized"
grep -Fqx future-input "$candidate_transcript_future.normalized"
test "$(wc -l <"$candidate_transcript_no_input.normalized")" -eq 1
test "$(wc -l <"$candidate_transcript_future.normalized")" -eq 2
echo "DEAD-ATTACH-REFUSAL-GREEN-7ca1"

test "$(run_count "$candidate_marker")" -eq 1
test "$(start_count "$candidate")" -eq 1
echo "NO-NEW-INCARNATION-GREEN-7ca1"

after_status="$(
  pty_at list --json |
    jq -er --arg id "$candidate" '.[] | select(.name == $id) | .status'
)"
after_pid="$(
  pty_at list --json |
    jq -r --arg id "$candidate" '.[] | select(.name == $id) | .pid // empty'
)"
test "$after_status" = "exited"
case "$after_pid" in
  "") ;;
  *[!0-9]*) exit 1 ;;
  *) ! pid_is_candidate_daemon "$after_pid" ;;
esac
! pid_is_candidate_daemon "$before_pid"
echo "DEAD-STATE-UNCHANGED-GREEN-7ca1"

cleanup
trap - EXIT
test "$(pty_at list --json | jq 'length')" -eq 0
echo "SYNTHETIC-ROOT-CLEAN-GREEN-7ca1"
