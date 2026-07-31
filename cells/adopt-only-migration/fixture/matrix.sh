#!/usr/bin/env bash
set -euo pipefail

root="${CATALOG:?CATALOG must be set}"
net="$root/net"
export PTY_ROOT="$net/pty"
export XDG_STATE_HOME="$root/state"

live_id="migrate.live.agent"
absent_id="migrate.absent.agent"
control_id="migrate.control.agent"
live_spec="$net/agents/migrate/live/agent.kdl"

pty_at() {
  env -u PTY_SESSION PTY_ROOT="$PTY_ROOT" pty "$@"
}

session() {
  pty_at list --json | jq -c --arg id "$1" '.[] | select(.name == $id)'
}

status_of() {
  session "$1" | jq -r '.status // empty'
}

pid_of() {
  session "$1" | jq -r '.pid // empty'
}

run_count() {
  file="$net/$1-count"
  test -f "$file" || {
    printf '0\n'
    return
  }
  cat "$file"
}

wait_status() {
  id="$1"
  expected="$2"
  for _ in $(seq 1 100); do
    status="$(status_of "$id")"
    test "$status" = "$expected" && return 0
    sleep 0.05
  done
  printf '%s did not reach status %s (last status: %s)\n' \
    "$id" "$expected" "${status:-missing}" >&2
  return 1
}

wait_count() {
  label="$1"
  expected="$2"
  for _ in $(seq 1 100); do
    test "$(run_count "$label")" -eq "$expected" && return 0
    sleep 0.05
  done
  printf '%s did not reach generation %s\n' "$label" "$expected" >&2
  return 1
}

retire() {
  spec="$1"
  grep -Fq 'retired #true' "$spec" ||
    sed -i '/role "worker"/a\\  retired #true' "$spec"
}

cleanup() {
  for identity in live absent control; do
    retire "$net/agents/migrate/$identity/agent.kdl" 2>/dev/null || true
  done
  st2 up --once --catalog "$net" --host migrate >/dev/null 2>&1 || true
  sleep 0.1
  st2 up --once --catalog "$net" --host migrate >/dev/null 2>&1 || true
  for id in "$live_id" "$absent_id" "$control_id"; do
    pty_at kill "$id" >/dev/null 2>&1 || true
    pty_at rm "$id" >/dev/null 2>&1 || true
  done
}
trap cleanup EXIT

# Seed exactly one pre-existing process generation before st2 sees the
# declaration. The declared launch command is therefore observable but must not
# execute during adoption.
mkdir -p "$PTY_ROOT"
CATALOG="$net" pty_at run -d --id "$live_id" --tag keep=true \
  --cwd "$net/workspace" -- bash "$net/task.sh" live >/dev/null
wait_status "$live_id" running
wait_count live 1
live_pid_before="$(pid_of "$live_id")"
test -n "$live_pid_before"

st2 up --once --catalog "$net" --host migrate >"$root/first-pass.out"

if
  test "$(status_of "$live_id")" = running &&
    test "$(pid_of "$live_id")" = "$live_pid_before" &&
    test "$(run_count live)" -eq 1 &&
    grep -Fq 'adopted (1): live' "$root/first-pass.out"
then
  echo "LIVE-ADOPTED-UNCHANGED-GREEN-a091"
fi

if
  test "$(run_count absent)" -eq 0 &&
    test -z "$(session "$absent_id")" &&
    grep -Fq 'held (1): migrate.absent.agent' "$root/first-pass.out"
then
  echo "ABSENT-ADOPT-ONLY-HELD-GREEN-a091"
fi

if
  wait_count control 1 &&
    test "$(status_of "$control_id")" = running &&
    grep -Fq "$control_id" "$root/first-pass.out"
then
  echo "ORDINARY-MISSING-LAUNCH-CONTROL-GREEN-a091"
fi

# The adopted process exits. Adopt-only must retain the dead record and refuse
# both collection and replacement.
pty_at kill "$live_id" >/dev/null
wait_status "$live_id" exited
live_record_before="$(session "$live_id")"
test "$(run_count live)" -eq 1

st2 up --once --catalog "$net" --host migrate >"$root/held-pass.out"

if
  test "$(run_count live)" -eq 1 &&
    test "$(status_of "$live_id")" = exited &&
    test "$(session "$live_id")" = "$live_record_before" &&
    grep -Fq 'held (2): migrate.absent.agent, migrate.live.agent' "$root/held-pass.out"
then
  echo "EXITED-ADOPTED-GENERATION-HELD-GREEN-a091"
fi

# This is the explicit authorization edge. The declaration becomes an ordinary
# service task; only now may st2 reap the exited record and cold-launch.
sed -i 's/lifecycle "adopt-only"/lifecycle "service"/' "$live_spec"
st2 up --once --catalog "$net" --host migrate >"$root/replacement-pass.out"

if
  wait_count live 2 &&
    test "$(status_of "$live_id")" = running &&
    test "$(pid_of "$live_id")" != "$live_pid_before" &&
    grep -Fq "$live_id" "$root/replacement-pass.out" &&
    test "$(run_count absent)" -eq 0
then
  echo "EXPLICIT-ORDINARY-REPLACEMENT-GREEN-a091"
fi

cleanup
trap - EXIT
test "$(pty_at list --json | jq 'length')" -eq 0
echo "SYNTHETIC-MIGRATION-ROOT-CLEAN-GREEN-a091"
