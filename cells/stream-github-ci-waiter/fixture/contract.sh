#!/usr/bin/env bash
set -euo pipefail

root="${CATALOG:?CATALOG must be set}"
net="$root/net"
export CATALOG="$net"
export ST_ROOT="$net"
export PTY_ROOT="$net/pty"
export XDG_STATE_HOME="$root/state"
export ST_AGENT=stream.worker
export STREAM_KEEP_ALIVE=0
real_st2="$(command -v st2)"

cleanup() {
  st2 down --catalog "$net" --host stream >/dev/null 2>&1 || true
  PTY_ROOT="$PTY_ROOT" pty rm stream.worker >/dev/null 2>&1 || true
}
trap cleanup EXIT

st2 validate --catalog "$net" --host stream --strict >/dev/null
export STREAM_GH_REPO=compoundingtech/st2 STREAM_GH_PR=285 STREAM_GH_POLL_SECONDS=0

run_fake() {
  local mode="$1" count_file="$2"
  shift 2
  PATH="$root/fake-bin:$PATH" FAKE_GH_MODE="$mode" FAKE_GH_COUNT_FILE="$count_file" \
    "$root/wait-gh-pr-ci.sh" "$@"
}
mkdir -p "$root/fake-bin"
ln -s "$root/fake-gh" "$root/fake-bin/gh"
chmod +x "$root/fake-gh" "$root/flaky-st2" "$root/wait-gh-pr-ci.sh"

created="$(STREAM_GH_MAX_ATTEMPTS=5 run_fake success "$root/success.count")"
jq -e '.status == "created" and .stream == "github-ci" and (.eventId | startswith("github-pr-285-1ca43e397f804277c553b08b4571408e82831bb4-success-"))' <<<"$created" >/dev/null
test "$(cat "$root/success.count")" -eq 3
filename="$(jq -r .filename <<<"$created")"
jq -e '.kind == "github-pr-ci" and .conclusion == "success" and .checks[0].state == "SUCCESS"' \
  <<<"$(tail -n 1 "$net/agents/stream/worker/resources/inbox/$filename")" >/dev/null

replay="$(STREAM_GH_MAX_ATTEMPTS=5 run_fake success "$root/replay.count")"
jq -e '.status == "deduplicated"' <<<"$replay" >/dev/null
test "$(jq -r .filename <<<"$replay")" = "$filename"
echo "GH-CI-RETRY-DEDUP-GREEN-b9e4"

delivery="$(PATH="$root/fake-bin:$PATH" FAKE_GH_MODE=success FAKE_GH_LINK_SUFFIX=/delivery \
  FAKE_GH_COUNT_FILE="$root/delivery-gh.count" FAKE_ST2_COUNT_FILE="$root/delivery-st2.count" \
  REAL_ST2="$real_st2" STREAM_ST2_BIN="$root/flaky-st2" STREAM_EMIT_INITIAL_BACKOFF_SECONDS=0 \
  STREAM_GH_MAX_ATTEMPTS=5 "$root/wait-gh-pr-ci.sh")"
jq -e '.status == "created"' <<<"$delivery" >/dev/null
test "$(cat "$root/delivery-st2.count")" -eq 3
delivery_file="$(jq -r .filename <<<"$delivery")"
test -e "$net/agents/stream/worker/resources/inbox/$delivery_file"
echo "GH-CI-DELIVERY-RETRY-GREEN-b9e4"

failed="$(STREAM_GH_MAX_ATTEMPTS=5 run_fake failure "$root/failure.count")"
jq -e '.status == "created" and (.eventId | contains("-failure-"))' <<<"$failed" >/dev/null
failed_file="$(jq -r .filename <<<"$failed")"
test ! -e "$net/agents/stream/worker/resources/inbox/$filename"
test -e "$net/agents/stream/worker/resources/archive/$filename"
grep -Fq '"conclusion":"failure"' "$net/agents/stream/worker/resources/inbox/$failed_file"
echo "GH-CI-FAILURE-SUPERSESSION-GREEN-b9e4"

set +e
STREAM_GH_MAX_ATTEMPTS=3 run_fake pending "$root/pending.count" >"$root/pending.out" 2>&1
pending_status="$?"
set -e
test "$pending_status" -eq 75
test "$(cat "$root/pending.count")" -eq 3
grep -Fq 'did not reach a terminal state after 3 attempts' "$root/pending.out"
test "$(find "$net/agents/stream/worker/resources/inbox" -type f | wc -l)" -eq 1
echo "GH-CI-TIMEOUT-NO-EVENT-GREEN-b9e4"

if test "${STREAM_GH_LIVE:-0}" = 1; then
  real_gh="$(command -v gh)"
  "$real_gh" auth status >/dev/null
  rm -f "$root/live.count"
  live="$(STREAM_GH_BIN="$real_gh" STREAM_GH_TRACE_FILE="$root/live-trace.jsonl" STREAM_GH_MAX_ATTEMPTS=700 STREAM_GH_POLL_SECONDS=2 "$root/wait-gh-pr-ci.sh")"
  jq -se 'any(.pending > 0) and (last | .pending == 0 and .unknown == 0)' "$root/live-trace.jsonl" >/dev/null
  jq -e '.status == "created" or .status == "deduplicated"' <<<"$live" >/dev/null
  live_file="$(jq -r .filename <<<"$live")"
  grep -Fq '"repo":"compoundingtech/st2"' "$net/agents/stream/worker/resources/inbox/$live_file"
  grep -Fq '"head":"1ca43e397f804277c553b08b4571408e82831bb4"' "$net/agents/stream/worker/resources/inbox/$live_file"
  grep -Fq '"conclusion":"success"' "$net/agents/stream/worker/resources/inbox/$live_file"
  echo "GH-CI-LIVE-PENDING-TERMINAL-GREEN-b9e4"
fi

cleanup
trap - EXIT
test "$(PTY_ROOT="$PTY_ROOT" pty list --json | jq 'length')" -eq 0
echo "GH-CI-CLEANUP-GREEN-b9e4"
