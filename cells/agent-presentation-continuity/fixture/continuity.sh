#!/usr/bin/env bash
set -euo pipefail

root="${CATALOG:?CATALOG must be set}"
net="$root/net"
spec="$net/agents/pc/worker/agent.kdl"
original="$root/worker.original.kdl"
pty_id="pc.worker"
export PTY_ROOT="$net/pty"
export XDG_STATE_HOME="$root/state"

cp "$spec" "$original"

pty_at() {
  env -u PTY_SESSION PTY_ROOT="$PTY_ROOT" pty "$@"
}

session() {
  pty_at list --json | jq -cer --arg id "$pty_id" '.[] | select(.name == $id)'
}

generation() {
  session | jq -c '{name,pid,createdAt}'
}

start_count() {
  jq -s '[.[] | select(.type == "session_start")] | length' "$PTY_ROOT/$pty_id.events.jsonl"
}

wait_running() {
  for _ in $(seq 1 100); do
    test "$(session | jq -r '.status')" = running && return 0
    sleep 0.05
  done
  echo "presentation fixture did not become ready" >&2
  return 1
}

retire() {
  grep -Fq 'retired #true' "$spec" || sed -i '/role "worker"/a\\  retired #true' "$spec"
}

cleanup() {
  if test -f "$spec"; then
    retire 2>/dev/null || true
    st2 up --once --catalog "$net" --host pc >/dev/null 2>&1 || true
  fi
  pty_at kill "$pty_id" >/dev/null 2>&1 || true
  pty_at rm "$pty_id" >/dev/null 2>&1 || true
  cp "$original" "$spec" 2>/dev/null || true
}
trap cleanup EXIT

st2 validate --catalog "$net" --host pc --strict >/dev/null
st2 agents --catalog "$net" --host pc --json >"$root/roster-absent.json"
jq -e '
  length == 2 and
  (.[] | select(.identity == "pc.worker") | .name == null and .description == null)
' "$root/roster-absent.json" >/dev/null
echo "PRESENTATION-AUTHORITY-GREEN-a128"

st2 up --once --catalog "$net" --host pc >"$root/launch.out"
grep -Fq 'launched (1): pc.worker' "$root/launch.out"
wait_running
before="$(generation)"
test "$(start_count)" -eq 1

st2 status "$pty_id" --set busy --catalog "$net" --host pc --as "$pty_id" >/dev/null
printf '%s\n' CONTEXT-NOW-a128 | st2 context write "$pty_id" --catalog "$net" --as "$pty_id"
st2 context append "$pty_id" --catalog "$net" --as "$pty_id" \
  --decision DECISION-a128 --why DECISION-WHY-a128
st2 resource add https://example.invalid/presentation-a128 \
  --catalog "$net" --as "$pty_id" --title PRESENTATION-RESOURCE-a128 \
  --tag presentation,continuity --relation output >"$root/resource-ref"

st2 message send "$pty_id" --catalog "$net" --host pc --as pc.sender \
  --subject ARCHIVED-a128 >/dev/null <<'MSG'
ARCHIVED-BODY-a128
MSG
archived_path=("$net/agents/pc/worker/resources/inbox/"*.md)
test "${#archived_path[@]}" -eq 1
archived_name="$(basename "${archived_path[0]}")"
st2 message archive "$pty_id" "$archived_name" --catalog "$net" --host pc \
  --as "$pty_id" >/dev/null
st2 message send "$pty_id" --catalog "$net" --host pc --as pc.sender \
  --subject UNREAD-a128 >/dev/null <<'MSG'
UNREAD-BODY-a128
MSG

for _ in $(seq 1 100); do
  pty_at peek --plain "$pty_id" 2>/dev/null | grep -Fq PRESENTATION-TRANSCRIPT-a128 && break
  sleep 0.05
done
pty_at peek --plain "$pty_id" | grep -Fq PRESENTATION-TRANSCRIPT-a128

add_fields() {
  sed -i '/role "worker"/a\\  description "Owns durable identity acceptance"\n  name "Evidence Worker"' "$spec"
}

assert_generation() {
  test "$(generation)" = "$before"
  test "$(start_count)" -eq 1
}

add_fields
st2 validate --catalog "$net" --host pc --strict >/dev/null
st2 up --once --catalog "$net" --host pc >"$root/add.out"
grep -Fq 'adopted (1): worker' "$root/add.out"
test -z "$(sed -n '/launched (/p;/torn down (/p' "$root/add.out")"
assert_generation
st2 agents --catalog "$net" --host pc --json >"$root/roster-added.json"
jq -e '
  .[] | select(.identity == "pc.worker") |
  .name == "Evidence Worker" and
  .description == "Owns durable identity acceptance"
' "$root/roster-added.json" >/dev/null

st2 up --once --catalog "$net" --host pc >"$root/repeat.out"
grep -Fq 'adopted (1): worker' "$root/repeat.out"
assert_generation

sed -i 's/name "Evidence Worker"/name "Shared Presentation"/' "$spec"
sed -i 's/description "Owns durable identity acceptance"/description "Owns changed identity acceptance"/' "$spec"
st2 up --once --catalog "$net" --host pc >"$root/change.out"
assert_generation
st2 agents --catalog "$net" --host pc --json >"$root/roster-changed.json"
jq -e '
  .[] | select(.identity == "pc.worker") |
  .name == "Shared Presentation" and
  .description == "Owns changed identity acceptance"
' "$root/roster-changed.json" >/dev/null

sed -i '/^  name "/d;/^  description "/d' "$spec"
st2 up --once --catalog "$net" --host pc >"$root/clear.out"
assert_generation
st2 agents --catalog "$net" --host pc --json >"$root/roster-cleared.json"
jq -e '
  .[] | select(.identity == "pc.worker") |
  .name == null and .description == null
' "$root/roster-cleared.json" >/dev/null
echo "PRESENTATION-ROSTER-GREEN-a128"
echo "PRESENTATION-GENERATION-GREEN-a128"

test "$(st2 status "$pty_id" --catalog "$net" --host pc --as "$pty_id")" = busy
st2 context read "$pty_id" --catalog "$net" --as "$pty_id" | grep -Fq CONTEXT-NOW-a128
st2 context read "$pty_id" --catalog "$net" --as "$pty_id" --decisions | grep -Fq DECISION-WHY-a128
st2 resource ls --catalog "$net" --as "$pty_id" | grep -Fq https://example.invalid/presentation-a128
test -f "$net/agents/pc/worker/resources/archive/$archived_name"
grep -Fq ARCHIVED-BODY-a128 "$net/agents/pc/worker/resources/archive/$archived_name"
grep -Fq UNREAD-BODY-a128 "$net/agents/pc/worker/resources/inbox/"*.md
pty_at peek --plain "$pty_id" | grep -Fq PRESENTATION-TRANSCRIPT-a128
echo "PRESENTATION-DURABILITY-GREEN-a128"

retire
st2 up --once --catalog "$net" --host pc >/dev/null
pty_at rm "$pty_id" >/dev/null 2>&1 || true
cp "$original" "$spec"
trap - EXIT
test "$(pty_at list --json | jq 'length')" -eq 0
echo "PRESENTATION-CLEANUP-GREEN-a128"
