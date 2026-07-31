#!/usr/bin/env bash
set -euo pipefail

catalog="${CATALOG:?CATALOG must be set}"
package_root="${EVALS_PTY_PR128_ROOT:?EVALS_PTY_PR128_ROOT must point to exact merged PTY PR128 source}"
expected_head="9eb958c5aae026d5c05690ab72b528662c55708d"
expected_package_lock="43189b5b5b1d560be4b9102d2ed0793d89b9b01dbb3bbd976948f10c6669118d"
expected_cli="3c3d655b713a6e1a40309eb1b45bb75a023e87dc6391f7dbaa54cefc3efb49ab"
expected_dist_cli="46285f9cb0212751ccc8344ba821038643c589c1b31a62cfd4354a5b56d2c5c3"
expected_dist_server="f7ec154a8f968077c19a3affb5c08bed101fc045fa53cce64178f5512c30711b"
pty_cli="$package_root/bin/pty"
root="$catalog/pty-live-recovery-root"
unsupported_root="$catalog/pty-live-recovery-unsupported-root"
live_command="$PWD/live.sh"
tracked_pids=()
tracked_start_tokens=()
client_pids=()
all_tracked_daemons_dead=false
cleanup_kill_fallbacks=0

mkdir -p "$root" "$unsupported_root"
chmod 0700 "$root"
chmod 0755 "$unsupported_root"

pty_at() {
  PTY_ROOT="$root" env -u PTY_SESSION -u PTY_SESSION_DIR "$pty_cli" "$@"
}

pty_at_unsupported() {
  PTY_ROOT="$unsupported_root" env -u PTY_SESSION -u PTY_SESSION_DIR "$pty_cli" "$@"
}

process_start_token() {
  local pid="$1"
  local start_ticks
  test -r "/proc/$pid/stat" || return 1
  start_ticks="$(awk '{ print $22 }' "/proc/$pid/stat")"
  test -n "$start_ticks" || return 1
  printf 'linux:%s\n' "$start_ticks"
}

track_pid() {
  local pid="$1"
  local start_token
  start_token="$(process_start_token "$pid")"
  tracked_pids+=("$pid")
  tracked_start_tokens+=("$start_token")
}

tracked_process_alive() {
  local index="$1"
  local pid="${tracked_pids[$index]}"
  local expected_start="${tracked_start_tokens[$index]}"
  local current_start
  current_start="$(process_start_token "$pid" 2>/dev/null)" || return 1
  test "$current_start" = "$expected_start"
}

wait_tracked_dead() {
  local index="$1"
  for _ in $(seq 1 80); do
    tracked_process_alive "$index" || return 0
    sleep 0.025
  done
  return 1
}

cleanup() {
  local pid index
  for pid in "${client_pids[@]}"; do
    kill "$pid" 2>/dev/null || true
    wait "$pid" 2>/dev/null || true
  done
  for index in "${!tracked_pids[@]}"; do
    if tracked_process_alive "$index"; then
      pid="${tracked_pids[$index]}"
      if ! kill -TERM "$pid" 2>/dev/null && tracked_process_alive "$index"; then
        printf 'failed to TERM tracked daemon %s\n' "$pid" >&2
        return 1
      fi
    fi
  done
  for index in "${!tracked_pids[@]}"; do
    if ! wait_tracked_dead "$index"; then
      pid="${tracked_pids[$index]}"
      if tracked_process_alive "$index"; then
        if ! kill -KILL "$pid" 2>/dev/null && tracked_process_alive "$index"; then
          printf 'failed to KILL tracked daemon %s\n' "$pid" >&2
          return 1
        fi
        ((cleanup_kill_fallbacks += 1))
        wait "$pid" 2>/dev/null || true
      fi
      wait_tracked_dead "$index" || {
        printf 'tracked daemon %s remained alive after TERM and KILL\n' "$pid" >&2
        return 1
      }
    fi
  done
  for index in "${!tracked_pids[@]}"; do
    tracked_process_alive "$index" && {
      printf 'tracked daemon %s remains alive\n' "${tracked_pids[$index]}" >&2
      return 1
    }
  done
  all_tracked_daemons_dead=true
  rm -rf -- "$root" "$unsupported_root"
}
trap cleanup EXIT

wait_running() {
  id="$1"
  for _ in $(seq 1 120); do
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
  expected="$2"
  for _ in $(seq 1 120); do
    test -f "$file" && grep -Fq "$expected" "$file" && return 0
    sleep 0.05
  done
  printf 'timed out waiting for %s in %s\n' "$expected" "$file" >&2
  return 1
}

wait_peek() {
  id="$1"
  expected="$2"
  for _ in $(seq 1 120); do
    pty_at peek --plain "$id" 2>/dev/null | grep -Fq "$expected" && return 0
    sleep 0.05
  done
  printf 'timed out waiting for %s from %s\n' "$expected" "$id" >&2
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

assert_registry_absent() {
  id="$1"
  test ! -e "$root/$id.sock"
  test ! -e "$root/$id.pid"
  test ! -e "$root/$id.json"
}

assert_exchange_absent() {
  id="$1"
  test ! -e "$root/.recovery/$id.request.json"
  test ! -e "$root/.recovery/$id.result.json"
  test ! -e "$root/$id.lock"
}

expect_recovery_failure() {
  id="$1"
  snapshot="$2"
  stderr_file="$3"
  set +e
  pty_at recover "$id" --snapshot "$snapshot" >/dev/null 2>"$stderr_file"
  rc=$?
  set -e
  test "$rc" -ne 0
}

start_private_session() {
  id="$1"
  marker="$2"
  pty_at run -d --id "$id" --tag keep=true -- \
    bash "$live_command" "$marker"
  wait_running "$id"
  wait_peek "$id" LIVE-RECOVERY-READY
  last_daemon_pid="$(jq -er '.daemonPid' "$root/$id.json")"
  track_pid "$last_daemon_pid"
}

test "$(git -C "$package_root" rev-parse HEAD)" = "$expected_head"
test -z "$(git -C "$package_root" status --porcelain)"
test "$(sha256sum "$package_root/package-lock.json" | awk '{ print $1 }')" = "$expected_package_lock"
test "$(sha256sum "$pty_cli" | awk '{ print $1 }')" = "$expected_cli"
test "$(sha256sum "$package_root/dist/cli.js" | awk '{ print $1 }')" = "$expected_dist_cli"
test "$(sha256sum "$package_root/dist/server.js" | awk '{ print $1 }')" = "$expected_dist_server"
echo "LIVE-RECOVERY-EXACT-PR128-GREEN-d42e"

"$pty_cli" recover --help | grep -Fq 'pty recover <name> --snapshot <metadata.json>'

candidate="live-recovery-candidate"
candidate_marker="$catalog/live-recovery-candidate-runs"
candidate_snapshot_1="$catalog/live-recovery-candidate-1.snapshot"
candidate_snapshot_2="$catalog/live-recovery-candidate-2.snapshot"
candidate_follower="$catalog/live-recovery-candidate-follower.transcript"
start_private_session "$candidate" "$candidate_marker"
candidate_pid="$last_daemon_pid"
cp "$root/$candidate.json" "$candidate_snapshot_1"
jq -e '
  .recovery.protocol == 1 and
  (.recovery.secret | type == "string" and length == 64) and
  (.recovery.processStartToken | type == "string" and length > 0) and
  (.recovery.launchIdentity | type == "string" and length == 64) and
  (.recovery.metadataRevision | type == "string" and length == 64) and
  (.recovery.rootDevice | type == "number") and
  (.recovery.rootInode | type == "number") and
  (.recovery.recoveryDirDevice | type == "number") and
  (.recovery.recoveryDirInode | type == "number")
' "$candidate_snapshot_1" >/dev/null
candidate_generation="$(jq -er '.generation' "$candidate_snapshot_1")"
candidate_start="$(jq -er '.recovery.processStartToken' "$candidate_snapshot_1")"
candidate_launch="$(jq -er '.recovery.launchIdentity' "$candidate_snapshot_1")"
candidate_secret_1="$(jq -er '.recovery.secret' "$candidate_snapshot_1")"
candidate_revision_1="$(jq -er '.recovery.metadataRevision' "$candidate_snapshot_1")"
echo "LIVE-RECOVERY-CAPABILITY-GREEN-d42e"

pty_at peek -f --plain "$candidate" >"$candidate_follower" 2>&1 &
candidate_follower_pid=$!
client_pids+=("$candidate_follower_pid")
wait_text "$candidate_follower" LIVE-RECOVERY-READY

unlink_registry "$candidate"
kill -0 "$candidate_pid"
pty_at recover "$candidate" --snapshot "$candidate_snapshot_1"
test "$(cat "$root/$candidate.pid")" -eq "$candidate_pid"
test "$(jq -er '.daemonPid' "$root/$candidate.json")" -eq "$candidate_pid"
test "$(jq -er '.generation' "$root/$candidate.json")" = "$candidate_generation"
test "$(jq -er '.recovery.processStartToken' "$root/$candidate.json")" = "$candidate_start"
test "$(jq -er '.recovery.launchIdentity' "$root/$candidate.json")" = "$candidate_launch"
test "$(jq -er '.recovery.secret' "$root/$candidate.json")" != "$candidate_secret_1"
test "$(jq -er '.recovery.metadataRevision' "$root/$candidate.json")" != "$candidate_revision_1"
kill -0 "$candidate_pid"
echo "LIVE-RECOVERY-IDENTITY-ROTATION-GREEN-d42e"

kill -0 "$candidate_follower_pid"
pty_at send "$candidate" --seq post-rebind --seq key:return
wait_text "$candidate_follower" LIVE-RECOVERY-ACK:post-rebind
pty_at peek --plain "$candidate" | grep -Fq LIVE-RECOVERY-ACK:post-rebind
echo "LIVE-RECOVERY-CONTINUITY-GREEN-d42e"

cp "$root/$candidate.json" "$candidate_snapshot_2"
unlink_registry "$candidate"
expect_recovery_failure "$candidate" "$candidate_snapshot_1" \
  "$catalog/live-recovery-replay.stderr"
assert_registry_absent "$candidate"
assert_exchange_absent "$candidate"
kill -0 "$candidate_pid"
pty_at recover "$candidate" --snapshot "$candidate_snapshot_2"
test "$(run_count "$candidate_marker")" -eq 1
test "$(start_count "$candidate")" -eq 1
echo "LIVE-RECOVERY-REPLAY-NO-DUPLICATE-GREEN-d42e"

stale="live-recovery-stale"
stale_marker="$catalog/live-recovery-stale-runs"
stale_snapshot="$catalog/live-recovery-stale.snapshot"
current_snapshot="$catalog/live-recovery-current.snapshot"
start_private_session "$stale" "$stale_marker"
stale_pid="$last_daemon_pid"
cp "$root/$stale.json" "$stale_snapshot"
pty_at tag "$stale" role=current strategy=permanent >/dev/null
cp "$root/$stale.json" "$current_snapshot"
test "$(jq -er '.recovery.metadataRevision' "$stale_snapshot")" != \
  "$(jq -er '.recovery.metadataRevision' "$current_snapshot")"
unlink_registry "$stale"
expect_recovery_failure "$stale" "$stale_snapshot" \
  "$catalog/live-recovery-stale.stderr"
assert_registry_absent "$stale"
assert_exchange_absent "$stale"
kill -0 "$stale_pid"
pty_at recover "$stale" --snapshot "$current_snapshot"
jq -e '.tags.role == "current" and .tags.strategy == "permanent"' \
  "$root/$stale.json" >/dev/null
test "$(run_count "$stale_marker")" -eq 1
test "$(start_count "$stale")" -eq 1
echo "LIVE-RECOVERY-REVISION-GREEN-d42e"

authenticated="live-recovery-authenticated"
authenticated_marker="$catalog/live-recovery-authenticated-runs"
authenticated_snapshot="$catalog/live-recovery-authenticated.snapshot"
tampered_snapshot="$catalog/live-recovery-tampered.snapshot"
start_private_session "$authenticated" "$authenticated_marker"
authenticated_pid="$last_daemon_pid"
cp "$root/$authenticated.json" "$authenticated_snapshot"
jq '.recovery.secret = ("00" * 32)' "$authenticated_snapshot" >"$tampered_snapshot"
unlink_registry "$authenticated"
expect_recovery_failure "$authenticated" "$tampered_snapshot" \
  "$catalog/live-recovery-tampered.stderr"
assert_registry_absent "$authenticated"
assert_exchange_absent "$authenticated"
kill -0 "$authenticated_pid"
pty_at recover "$authenticated" --snapshot "$authenticated_snapshot"
test "$(run_count "$authenticated_marker")" -eq 1
test "$(start_count "$authenticated")" -eq 1
echo "LIVE-RECOVERY-AUTHENTICATION-GREEN-d42e"

privacy="live-recovery-privacy"
privacy_marker="$catalog/live-recovery-privacy-runs"
privacy_snapshot_1="$catalog/live-recovery-privacy-1.snapshot"
privacy_snapshot_2="$catalog/live-recovery-privacy-2.snapshot"
start_private_session "$privacy" "$privacy_marker"
privacy_pid="$last_daemon_pid"
cp "$root/$privacy.json" "$privacy_snapshot_1"
unlink_registry "$privacy"
chmod 0755 "$root/.recovery"
expect_recovery_failure "$privacy" "$privacy_snapshot_1" \
  "$catalog/live-recovery-private-dir.stderr"
assert_registry_absent "$privacy"
assert_exchange_absent "$privacy"
kill -0 "$privacy_pid"
chmod 0700 "$root/.recovery"
pty_at recover "$privacy" --snapshot "$privacy_snapshot_1"

cp "$root/$privacy.json" "$privacy_snapshot_2"
unlink_registry "$privacy"
chmod 0755 "$root"
expect_recovery_failure "$privacy" "$privacy_snapshot_2" \
  "$catalog/live-recovery-private-root.stderr"
assert_registry_absent "$privacy"
assert_exchange_absent "$privacy"
kill -0 "$privacy_pid"
chmod 0700 "$root"
pty_at recover "$privacy" --snapshot "$privacy_snapshot_2"
test "$(run_count "$privacy_marker")" -eq 1
test "$(start_count "$privacy")" -eq 1
echo "LIVE-RECOVERY-PRIVACY-GREEN-d42e"

unsupported="live-recovery-unsupported"
unsupported_marker="$catalog/live-recovery-unsupported-runs"
unsupported_snapshot="$catalog/live-recovery-unsupported.snapshot"
PTY_ROOT="$unsupported_root" env -u PTY_SESSION -u PTY_SESSION_DIR \
  "$pty_cli" run -d --id "$unsupported" --tag keep=true -- \
  bash "$live_command" "$unsupported_marker"
for _ in $(seq 1 120); do
  test -f "$unsupported_root/$unsupported.json" && break
  sleep 0.05
done
test -f "$unsupported_root/$unsupported.json"
jq -e '.recovery == null' "$unsupported_root/$unsupported.json" >/dev/null
unsupported_pid="$(jq -er '.daemonPid' "$unsupported_root/$unsupported.json")"
track_pid "$unsupported_pid"
cp "$unsupported_root/$unsupported.json" "$unsupported_snapshot"
rm "$unsupported_root/$unsupported.sock" \
  "$unsupported_root/$unsupported.pid" \
  "$unsupported_root/$unsupported.json"
set +e
pty_at_unsupported recover "$unsupported" --snapshot "$unsupported_snapshot" \
  >/dev/null 2>"$catalog/live-recovery-unsupported.stderr"
unsupported_rc=$?
set -e
test "$unsupported_rc" -ne 0
grep -Fq 'snapshot does not advertise supported recovery' \
  "$catalog/live-recovery-unsupported.stderr"
kill -0 "$unsupported_pid"
test "$(run_count "$unsupported_marker")" -eq 1
test ! -e "$unsupported_root/$unsupported.sock"
test ! -e "$unsupported_root/$unsupported.pid"
test ! -e "$unsupported_root/$unsupported.json"
echo "LIVE-RECOVERY-UNSUPPORTED-GREEN-d42e"

cleanup_sentinel_log="$catalog/live-recovery-cleanup-sentinel.log"
captured_daemon_count="${#tracked_pids[@]}"
perl -e '$|=1; $SIG{TERM}="IGNORE"; print "CLEANUP-SENTINEL-READY\n"; sleep 1 while 1' \
  >"$cleanup_sentinel_log" 2>&1 &
cleanup_sentinel_pid=$!
wait_text "$cleanup_sentinel_log" CLEANUP-SENTINEL-READY
track_pid "$cleanup_sentinel_pid"
tracked_process_count="${#tracked_pids[@]}"

cleanup
trap - EXIT
test "$all_tracked_daemons_dead" = true
test "$cleanup_kill_fallbacks" -ge 1
test ! -e "$root"
test ! -e "$unsupported_root"
jq -n \
  --arg sourceHead "$expected_head" \
  --arg packageLockSha256 "$expected_package_lock" \
  --arg cliSha256 "$expected_cli" \
  --arg distCliSha256 "$expected_dist_cli" \
  --arg distServerSha256 "$expected_dist_server" \
  --argjson trackedDaemons "$captured_daemon_count" \
  --argjson trackedProcesses "$tracked_process_count" \
  --argjson killFallbacks "$cleanup_kill_fallbacks" \
  '{
    dependency: {
      sourceHead: $sourceHead,
      packageLockSha256: $packageLockSha256,
      cliSha256: $cliSha256,
      distCliSha256: $distCliSha256,
      distServerSha256: $distServerSha256,
      evidenceClass: "local-exact-source-build"
    },
    coverage: {
      positiveRecovery: true,
      replayRefusal: true,
      staleRevisionRefusal: true,
      authenticationRefusal: true,
      privateRootRefusal: true,
      privateRecoveryDirectoryRefusal: true,
      unsupportedRefusal: true,
      establishedClientContinuity: true,
      duplicateLaunches: 0
    },
    modelCalls: 0,
    cleanup: {
      rootsAbsent: true,
      trackedDaemons: $trackedDaemons,
      trackedProcesses: $trackedProcesses,
      allTrackedDaemonsDead: true,
      killFallbacks: $killFallbacks
    }
  }' >"$catalog/pty-live-recovery-receipt.json"
echo "LIVE-RECOVERY-CLEANUP-MODEL-FREE-GREEN-d42e"
