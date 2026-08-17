#!/usr/bin/env bash
set -euo pipefail

ROOT="${CATALOG:?CATALOG must be set}"
SPEC="$ROOT/agent-spec.kdl"
W="$ROOT/worker"
LOG="$ROOT/.oracle/controller.log"
WORKER="ahr.worker"
SUP="ahr.sup"
A_URI="github-issue://eval/names-normalize"
B_URI="github-issue://eval/names-format-label"
mkdir -p "$ROOT/.oracle"
: >"$LOG"

worker_pid() {
  st2 pty ls --json 2>/dev/null |
    node -e '
      const sessions = JSON.parse(require("node:fs").readFileSync(0, "utf8"));
      const worker = sessions.find((session) => session.name === "ahr.worker" && session.status === "running");
      if (worker?.pid) process.stdout.write(String(worker.pid));
    '
}

worker_created_at() {
  st2 pty ls --json 2>/dev/null |
    node -e '
      const sessions = JSON.parse(require("node:fs").readFileSync(0, "utf8"));
      const worker = sessions.find((session) => session.name === "ahr.worker" && session.status === "running");
      if (worker?.createdAt) process.stdout.write(String(worker.createdAt));
    '
}

wait_for_pid() {
  local pid=""
  for _ in $(seq 1 300); do
    pid="$(worker_pid || true)"
    if [ -n "$pid" ]; then
      printf '%s\n' "$pid"
      return 0
    fi
    sleep 1
  done
  return 1
}

busdir() {
  local id="$1" d=""
  d="$(ls -d "$ST_ROOT"/*."$id" "$ST_ROOT/$id" 2>/dev/null | head -1 || true)"
  printf '%s\n' "${d:-$ST_ROOT/$id}"
}

find_report() {
  local owner_id="$1" from="$2" token="$3" owner file
  owner="$(busdir "$owner_id")"
  while IFS= read -r file; do
    [ -n "$file" ] || continue
    if grep -Eq "^from:[[:space:]]*$from([[:space:]]|$)" "$file" &&
       grep -Fq "$token" "$file"; then
      printf '%s\n' "$file"
      return 0
    fi
  done < <(grep -lRF "$token" "$owner/inbox" "$owner/archive" 2>/dev/null || true)
  return 1
}

wait_for_report() {
  local token="$1"
  for _ in $(seq 1 600); do
    if find_report "$SUP" "$WORKER" "$token" >/dev/null; then
      return 0
    fi
    sleep 1
  done
  return 1
}

wait_for_inbox() {
  local owner="$1" from="$2" token="$3" file=""
  for _ in $(seq 1 600); do
    file="$(find_report "$owner" "$from" "$token" || true)"
    if [ -n "$file" ]; then
      printf '%s\n' "$file"
      return 0
    fi
    sleep 1
  done
  return 1
}

snapshot() {
  local event="$1" pid created_at head intent_uri focus_state
  pid="$(worker_pid || true)"
  created_at="$(worker_created_at || true)"
  head="$(git -C "$W" rev-parse HEAD 2>/dev/null || true)"
  intent_uri="$(sed -nE 's/^[[:space:]]*resource "intent".* uri="([^"]+)".*/\1/p' "$SPEC")"
  if grep -Fqx '  focus "intent"' "$SPEC"; then
    focus_state="intent:$intent_uri"
  else
    focus_state="none"
  fi
  printf 'event=%s pid=%s created_at=%s session=%s head=%s intent=%s focus=%s epoch=%s\n' \
    "$event" "$pid" "$created_at" "$WORKER" "$head" "$intent_uri" "$focus_state" "$(date +%s)" >>"$LOG"
}

rebind_intent() {
  local uri="$1" tmp="$SPEC.next"
  awk -v uri="$uri" '
    /^[[:space:]]*resource "intent"/ {
      print "  resource \"intent\" uri=\"" uri "\""
      next
    }
    { print }
  ' "$SPEC" >"$tmp"
  mv "$tmp" "$SPEC"
}

remove_focus() {
  local tmp="$SPEC.next"
  awk '!/^[[:space:]]*focus "intent"/' "$SPEC" >"$tmp"
  mv "$tmp" "$SPEC"
}

notify_change() {
  st2 message send "$WORKER" --as ahr.controller --subject "durable resources changed" \
    -m "Durable Agent Spec resources changed. Reread the spec and act only on its current focus binding." \
    >/dev/null
}

kickoff="$(wait_for_inbox "ahr.controller" "requester" "Begin the work declared in durable context")"
st2 message read "$(basename "$kickoff")" >/dev/null
st2 message archive "$(basename "$kickoff")" >/dev/null
st2 message send "$SUP" --as ahr.controller --subject "begin durable work" \
  -m "Begin the work declared in durable context. Coordinate it end-to-end and report verified evidence to the controller." \
  >/dev/null

initial_pid="$(wait_for_pid)"
snapshot "boot"

wait_for_report "RESOURCE_DONE uri=$A_URI"
test "$(git -C "$W" log -1 --format=%s)" = "feat: add normalize-name"
test -z "$(git -C "$W" status --porcelain)"
snapshot "phase-a-complete"

rebind_intent "$B_URI"
snapshot "rebind-b"
notify_change

wait_for_report "RESOURCE_DONE uri=$B_URI"
test "$(git -C "$W" log -1 --format=%s)" = "feat: add format-label"
test -z "$(git -C "$W" status --porcelain)"
snapshot "phase-b-complete"

remove_focus
snapshot "remove-focus"
test "$(worker_pid)" = "$initial_pid"
notify_change

wait_for_report "RESOURCE_IDLE"
snapshot "idle"
sleep 3
snapshot "settled"

a_commit="$(git -C "$W" rev-list --reverse "$(<"$ROOT/.oracle/base")"..HEAD | sed -n '1p')"
b_commit="$(git -C "$W" rev-parse HEAD)"
receipt="HOT_RESOURCE_VERIFIED A_URI=$A_URI A_COMMIT=$a_commit B_URI=$B_URI B_COMMIT=$b_commit RESOURCE_IDLE"
evidence="$(wait_for_inbox "ahr.controller" "$SUP" "$receipt")"
st2 message read "$(basename "$evidence")" >/dev/null
st2 message archive "$(basename "$evidence")" >/dev/null
snapshot "ready-to-close"
st2 message send requester --as ahr.controller --subject "hot resource eval complete" \
  -m "$receipt same_worker_pid=$initial_pid tests=pass" >/dev/null
