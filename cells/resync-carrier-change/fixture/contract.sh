#!/usr/bin/env bash
set -euo pipefail

root="${CATALOG:?CATALOG must be set}"
net="$root/net"
agent_dir="$net/agents/rz/worker"
declaration="$agent_dir/agent.kdl"
goal="$agent_dir/resources/goal.md"
journal="$agent_dir/resources/context/journal.md"
readiness="$agent_dir/resources/readiness.txt"
inbox="$agent_dir/resources/inbox"
archive="$agent_dir/resources/archive"
original="$root/resync-carrier-change.original"
export CATALOG="$net"
export ST_ROOT="$net"
export PTY_ROOT="$net/pty"
export XDG_STATE_HOME="$root/state"

sup_pid=""
cleanup() {
  if [[ -n "$sup_pid" ]]; then
    kill -TERM "$sup_pid" 2>/dev/null || true
  fi
  st2 down --catalog "$net" --host rz >/dev/null 2>&1 || true
  pty rm rz.worker >/dev/null 2>&1 || true
}
trap cleanup EXIT

cp "$declaration" "$original"

# The goal carrier deliberately does not exist yet: whatever the supervisor seeds, it seeds as
# absent, so the first creation is always a content transition (absent -> present).

check_reserved_refused() {
  local catalog="$root/reserved-refused"
  mkdir -p "$catalog/agents/rz/worker"
  cat >"$catalog/agents/rz/worker/agent.kdl" <<'KDL'
agent "worker" {
  host "rz"
  command "true"
  stream "resync" {}
}
KDL
  set +e
  st2 validate --catalog "$catalog" --host rz --strict >"$root/reserved.out" 2>&1
  local status="$?"
  set -e
  test "$status" -ne 0
  grep -Fq "reserved for built-in resync events" "$root/reserved.out"
}
check_reserved_refused
echo "RESYNC-RESERVED-GREEN-c4a9"

# Resident supervisor: the resync watcher lives in the up loop, not in one-shot passes.
st2 up --catalog "$net" --host rz >"$root/supervisor.out" 2>&1 &
sup_pid=$!

wait_running() {
  local deadline=$((SECONDS + 30))
  while ((SECONDS < deadline)); do
    if st2 tasks --catalog "$net" --host rz --json 2>/dev/null \
      | jq -e '[.tasks[] | select((.runtimeId | startswith("rz.worker")) and .runtime.state == "running")] | length > 0' >/dev/null; then
      return 0
    fi
    sleep 0.25
  done
  echo "seat never reached running state" >&2
  return 1
}
wait_running
wait_watcher_ready() {
  local deadline=$((SECONDS + 30))
  local generation=0
  while ((SECONDS < deadline)); do
    generation=$((generation + 1))
    printf 'readiness %s\n' "$generation" >"$readiness"
    sleep 0.25
    if find "$inbox" -maxdepth 1 -type f -exec grep -l '^key: readiness$' {} \; 2>/dev/null | grep -q .; then
      return 0
    fi
  done
  echo "resync watcher never observed readiness carrier" >&2
  return 1
}
wait_watcher_ready

goal_event_files() {
  local directory="$1"
  find "$directory" -maxdepth 1 -type f 2>/dev/null | while read -r f; do
    if grep -q '^stream: resync$' "$f" && grep -q '^key: goal$' "$f"; then
      echo "$f"
    fi
  done
}

count_goal_events() {
  goal_event_files "$1" | wc -l
}

latest_goal_event_id() {
  goal_event_files "$inbox" | while read -r f; do
    sed -n 's/^event-id: //p' "$f"
  done | sort | tail -1
}

wait_for() {
  local description="$1"
  local probe="$2"
  local deadline=$((SECONDS + 20))
  while ((SECONDS < deadline)); do
    if eval "$probe"; then
      return 0
    fi
    sleep 0.25
  done
  echo "$description not observed within 20s" >&2
  return 1
}

# First change: creating the goal carrier emits exactly one event.
mkdir -p "$(dirname "$goal")"
printf 'mission v1\n' >"$goal"
wait_for "first resync event" 'test "$(count_goal_events "$inbox")" -ge 1'
sleep 1
test "$(count_goal_events "$inbox")" -eq 1
echo "RESYNC-FIRST-CHANGE-GREEN-c4a9"

equal_bytes_id="$(latest_goal_event_id)"

# Equal-byte rewrite: digest identity deduplicates to no wake.
printf 'mission v1\n' >"$goal"
sleep 1.5
test "$(count_goal_events "$inbox")" -eq 1
test "$(latest_goal_event_id)" = "$equal_bytes_id"
echo "RESYNC-EQUAL-BYTES-SILENT-GREEN-c4a9"

# Agent-authored store: silent by classification.
mkdir -p "$(dirname "$journal")"
printf 'entry one\n' >"$journal"
sleep 1.5
test "$(count_goal_events "$inbox")" -eq 1
if grep -rq 'resources/context' "$inbox" 2>/dev/null; then
  echo "context store unexpectedly notified" >&2
  exit 1
fi
echo "RESYNC-AUTHORED-STORE-SILENT-GREEN-c4a9"

# Changed content: fresh identity under the same key; supersession keeps one unread head.
printf 'mission v2\n' >"$goal"
wait_for "superseding resync event" 'test "$(count_goal_events "$inbox")" -eq 1 && test "$(latest_goal_event_id)" != "$equal_bytes_id"'
test -n "$(find "$archive" -maxdepth 1 -type f 2>/dev/null -exec grep -l '^key: goal$' {} \;)"
echo "RESYNC-SUPERSEDE-GREEN-c4a9"

# Configuration-management style replacement of the declaration: write-then-rename.
staged="$agent_dir/agent.kdl.new"
sed 's/Standing mission./Standing mission, amended./' "$declaration" >"$staged"
mv "$staged" "$declaration"
wait_for "declaration resync event" 'find "$inbox" -maxdepth 1 -type f -exec grep -l "^key: declaration$" {} \; | grep -q .'
echo "RESYNC-DECLARATION-GREEN-c4a9"

kill -TERM "$sup_pid"
for _ in $(seq 1 40); do
  kill -0 "$sup_pid" 2>/dev/null || break
  sleep 0.25
done
kill -0 "$sup_pid" 2>/dev/null && {
  echo "resident supervisor did not terminate" >&2
  exit 1
}
sup_pid=""
st2 down --catalog "$net" --host rz >/dev/null 2>&1
echo "RESYNC-CLEANUP-GREEN-c4a9"
