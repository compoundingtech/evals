#!/usr/bin/env bash
set -euo pipefail

root="${CATALOG:?CATALOG must be set}/attach-only-pty"
candidate="attach-only-dead"
control="legacy-dead"
candidate_marker="$CATALOG/attach-only-runs"
control_marker="$CATALOG/legacy-runs"
candidate_transcript="$CATALOG/attach-only.transcript"
control_transcript="$CATALOG/legacy.transcript"
once="$PWD/once.sh"

mkdir -p "$root"

pty_at() {
  PTY_ROOT="$root" env -u PTY_SESSION pty "$@"
}

cleanup() {
  for id in "$candidate" "$control"; do
    pty_at kill "$id" >/dev/null 2>&1 || true
    pty_at rm "$id" >/dev/null 2>&1 || true
  done
}
trap cleanup EXIT

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

if pty attach --help | grep -Eq '(^|[[:space:]])--no-restart([[:space:]]|$)'; then
  echo "ATTACH-ONLY-SURFACE-GREEN-7ca1"
else
  echo "attach --no-restart is not advertised" >&2
fi

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
! kill -0 "$before_pid" 2>/dev/null

set +e
printf 'future-input\n' |
  timeout 10 script -qefc \
    "env -u PTY_SESSION PTY_ROOT='$root' pty attach --no-restart '$candidate'" \
    /dev/null >"$candidate_transcript" 2>&1
candidate_rc=$?
set -e

test "$candidate_rc" -ne 0
test "$candidate_rc" -ne 124
! grep -Fq 'Restart? [Y/n]' "$candidate_transcript"
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
  *) ! kill -0 "$after_pid" 2>/dev/null ;;
esac
! kill -0 "$before_pid" 2>/dev/null
echo "DEAD-STATE-UNCHANGED-GREEN-7ca1"

cleanup
trap - EXIT
test "$(pty_at list --json | jq 'length')" -eq 0
echo "SYNTHETIC-ROOT-CLEAN-GREEN-7ca1"
