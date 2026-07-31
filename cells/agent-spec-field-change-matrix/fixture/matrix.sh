#!/usr/bin/env bash
set -uo pipefail

root="${CATALOG:?CATALOG must be set}"
manifest="$root/cases.tsv"
cases_root="$root/cases"
mkdir -p "$cases_root"

case_dir() {
  printf '%s/%s\n' "$cases_root" "$1"
}

case_env() {
  id="$1"
  shift
  dir="$(case_dir "$id")"
  CATALOG="$dir/catalog" \
    XDG_STATE_HOME="$dir/state" \
    PTY_ROOT="$dir/pty" \
    "$@"
}

initialize_case() {
  id="$1"
  dir="$(case_dir "$id")"
  mkdir -p "$dir/catalog" "$dir/state" "$dir/pty" "$dir/work-a" "$dir/work-b"
  cat >"$dir/task.sh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
label="${1:?label required}"
count_file="${2:?count file required}"
count=0
test ! -f "$count_file" || count="$(cat "$count_file")"
count=$((count + 1))
printf '%s\n' "$count" >"$count_file"
printf '%s\n' "$$" >"${count_file}.pid"
printf '%s\n' "$PWD" >"${count_file}.cwd"
trap 'exit 0' TERM INT
while :; do sleep 1; done
SH
  chmod +x "$dir/task.sh"
}

write_single_exec() {
  id="$1"
  host="$2"
  identity="$3"
  role="$4"
  type="$5"
  workspace="$6"
  task_name="$7"
  task_id="$8"
  label="$9"
  agent_extra="${10:-}"
  task_extra="${11:-}"
  dir="$(case_dir "$id")"
  spec="$dir/catalog/agents/$host/$identity/agent.kdl"
  mkdir -p "$(dirname "$spec")"
  {
    printf 'agent "%s" {\n' "$identity"
    printf '  host "%s"\n' "$host"
    printf '  role "%s"\n' "$role"
    printf '  type "%s"\n' "$type"
    printf '  workspace "%s"\n' "$workspace"
    test -z "$agent_extra" || printf '%s\n' "$agent_extra"
    printf '  exec "%s" {\n' "$task_name"
    test "$task_id" = "-" || printf '    id "%s"\n' "$task_id"
    printf '    command "exec bash \\"%s/task.sh\\" \\"%s\\" \\"%s/%s-count\\""\n' \
      "$dir" "$label" "$dir" "$label"
    test -z "$task_extra" || printf '%s\n' "$task_extra"
    printf '  }\n'
    printf '}\n'
  } >"$spec"
  printf '%s\n' "$spec"
}

write_two_exec() {
  id="$1"
  host="$2"
  identity="$3"
  workspace="$4"
  first_name="$5"
  first_id="$6"
  first_label="$7"
  second_name="$8"
  second_id="$9"
  second_label="${10}"
  retired="${11:-false}"
  dir="$(case_dir "$id")"
  spec="$dir/catalog/agents/$host/$identity/agent.kdl"
  mkdir -p "$(dirname "$spec")"
  {
    printf 'agent "%s" {\n' "$identity"
    printf '  host "%s"\n' "$host"
    printf '  role "worker"\n'
    printf '  type "service"\n'
    printf '  workspace "%s"\n' "$workspace"
    test "$retired" != true || printf '  retired #true\n'
    for task in first second; do
      if test "$task" = first; then
        name="$first_name" task_id="$first_id" label="$first_label"
      else
        name="$second_name" task_id="$second_id" label="$second_label"
      fi
      test "$name" = "-" && continue
      printf '  exec "%s" {\n' "$name"
      test "$task_id" = "-" || printf '    id "%s"\n' "$task_id"
      printf '    command "exec bash \\"%s/task.sh\\" \\"%s\\" \\"%s/%s-count\\""\n' \
        "$dir" "$label" "$dir" "$label"
      printf '  }\n'
    done
    printf '}\n'
  } >"$spec"
  printf '%s\n' "$spec"
}

run_once() {
  id="$1"
  host="$2"
  label="$3"
  dir="$(case_dir "$id")"
  case_env "$id" st2 up --once --catalog "$dir/catalog" --host "$host" \
    >"$dir/$label.out" 2>"$dir/$label.err"
}

validate_case() {
  id="$1"
  host="$2"
  label="$3"
  dir="$(case_dir "$id")"
  case_env "$id" st2 validate --catalog "$dir/catalog" --host "$host" \
    >"$dir/$label.out" 2>"$dir/$label.err"
}

tasks_json() {
  id="$1"
  host="$2"
  case_env "$id" st2 tasks --json --catalog "$(case_dir "$id")/catalog" --host "$host"
}

task_pid() {
  id="$1"
  host="$2"
  runtime_id="$3"
  tasks_json "$id" "$host" 2>/dev/null |
    jq -r --arg runtime_id "$runtime_id" \
      '.tasks[]? | select(.runtimeId == $runtime_id) | .runtime.pid // empty'
}

task_generation() {
  id="$1"
  host="$2"
  runtime_id="$3"
  tasks_json "$id" "$host" 2>/dev/null |
    jq -r --arg runtime_id "$runtime_id" \
      '.tasks[]? | select(.runtimeId == $runtime_id) | .runtime.generationId // empty'
}

wait_pid() {
  id="$1"
  host="$2"
  runtime_id="$3"
  for _ in $(seq 1 100); do
    pid="$(task_pid "$id" "$host" "$runtime_id")"
    if test -n "$pid" && kill -0 "$pid" 2>/dev/null; then
      printf '%s\n' "$pid"
      return 0
    fi
    sleep 0.05
  done
  return 1
}

wait_dead() {
  pid="$1"
  for _ in $(seq 1 100); do
    kill -0 "$pid" 2>/dev/null || return 0
    sleep 0.05
  done
  return 1
}

wait_file() {
  path="$1"
  for _ in $(seq 1 100); do
    test -s "$path" && return 0
    sleep 0.05
  done
  return 1
}

stop_exact_pid() {
  pid="$1"
  case "$pid" in
    ''|*[!0-9]*) return 1 ;;
  esac
  kill -TERM -- "-$pid" 2>/dev/null || kill -TERM "$pid" 2>/dev/null || true
  wait_dead "$pid"
}

process_generation_token() {
  pid="$1"
  start_ticks="$(awk '{print $22}' "/proc/$pid/stat")"
  printf '%s:%s\n' "$pid" "$start_ticks"
}

same_file_contents() {
  first="$1"
  second="$2"
  first_sha="$(sha256sum "$first" | awk '{print $1}')"
  second_sha="$(sha256sum "$second" | awk '{print $1}')"
  test "$first_sha" = "$second_sha"
}

message_count() {
  id="$1"
  identity="$2"
  case_env "$id" st2 message ls "$identity" --json 2>/dev/null |
    jq 'length' 2>/dev/null || printf '0\n'
}

assert_no_reconcile_action() {
  output="$1"
  ! grep -Eq '^  (launched|torn down|gc|held|flapping) \(' "$output"
}

capture_change_event() {
  id="$1"
  host="$2"
  identity="$3"
  change_class="$4"
  output="$5"
  shift 5
  dir="$(case_dir "$id")"
  rows="$(case_env "$id" st2 message ls "$host.$identity" --json)" || return 1
  test "$(printf '%s\n' "$rows" | jq 'length')" -eq 1 || {
    printf 'expected exactly one %s event for %s, observed: %s\n' \
      "$change_class" "$host.$identity" "$rows" >&2
    return 1
  }
  filename="$(printf '%s\n' "$rows" | jq -r '.[0].filename')"
  [[ "$filename" =~ ^[0-9]{13}-[0-9a-z]{6}\.md$ ]] || return 1
  inbox="$dir/catalog/agents/$host/$identity/resources/inbox/$filename"
  test -s "$inbox" || return 1
  case_env "$id" st2 message read "$host.$identity" "$filename" --json >"$output" || return 1
  jq -r '[.filename, .from, .subject, (.tags[]?), .body] |
    map(select(type == "string" and length > 0)) | join("\n")' "$output" >"$output.text" || return 1
  tr '[:upper:]' '[:lower:]' <"$output.text" >"$output.lower" || return 1
  grep -Fq "$change_class" "$output.lower" || return 1
  grep -Fq "$host.$identity" "$output.text" || return 1
  for expected in "$@"; do
    grep -Fq "$expected" "$output.text" || return 1
  done
  printf '%s\n' "$filename"
}

assert_event_omits() {
  output="$1"
  shift
  for forbidden in "$@"; do
    if grep -Fq "$forbidden" "$output.text"; then
      return 1
    fi
  done
}

archive_and_replay_event() {
  id="$1"
  host="$2"
  identity="$3"
  filename="$4"
  dir="$(case_dir "$id")"
  agent_dir="$dir/catalog/agents/$host/$identity"
  case_env "$id" st2 message archive "$host.$identity" "$filename" >/dev/null || return 1
  test -s "$agent_dir/resources/archive/$filename" || return 1
  cp "$agent_dir/resources/archive/$filename" "$agent_dir/resources/inbox/$filename" || return 1
  test "$(message_count "$id" "$host.$identity")" -eq 0 || return 1
  case_env "$id" st2 message archive "$host.$identity" "$filename" >/dev/null || return 1
  test ! -e "$agent_dir/resources/inbox/$filename"
}

cleanup_case() {
  id="$1"
  dir="$(case_dir "$id")"
  while IFS= read -r pid_file; do
    pid="$(cat "$pid_file" 2>/dev/null || true)"
    case "$pid" in
      ''|*[!0-9]*) continue ;;
    esac
    kill -0 "$pid" 2>/dev/null && stop_exact_pid "$pid" || true
  done < <(find "$dir" -type f -path '*/state/st2/*/exec/*.pid' -print 2>/dev/null)
  while IFS= read -r pty_root; do
    while IFS= read -r name; do
      test -n "$name" || continue
      PTY_ROOT="$pty_root" pty kill "$name" >/dev/null 2>&1 || true
      PTY_ROOT="$pty_root" pty rm "$name" >/dev/null 2>&1 || true
    done < <(PTY_ROOT="$pty_root" pty list --json 2>/dev/null | jq -r '.[].name' 2>/dev/null || true)
    test "$(PTY_ROOT="$pty_root" pty list --json 2>/dev/null | jq 'length')" -eq 0
  done < <(find "$dir" -type d -name pty -print 2>/dev/null)
}

probe_source_noop_heals() {
  id="source-noop-heals" host="fm01" identity="agent" runtime_id="$host.$identity.work"
  initialize_case "$id"
  dir="$(case_dir "$id")"
  spec="$(write_single_exec "$id" "$host" "$identity" worker service "$dir/work-a" work "$runtime_id" noop)"
  run_once "$id" "$host" initial
  pid_before="$(wait_pid "$id" "$host" "$runtime_id")"
  generation_before="$(task_generation "$id" "$host" "$runtime_id")"
  test -n "$generation_before"

  # Move both source path and source form while keeping every normalized effect equal. Explicit
  # workspace and cwd values ensure the old KDL path is not an implicit launch input.
  moved="$dir/moved.json.tmp"
  jq -n \
    --arg identity "$identity" \
    --arg host "$host" \
    --arg workspace "$dir/work-a" \
    --arg runtime_id "$runtime_id" \
    --arg command "exec bash \"$dir/task.sh\" \"noop\" \"$dir/noop-count\"" \
    '{
      identity: $identity,
      host: $host,
      role: "worker",
      type: "service",
      workspace: $workspace,
      exec: {
        work: {
          id: $runtime_id,
          command: $command,
          cwd: $workspace
        }
      }
    }' >"$moved"
  rm -f "$spec"
  mkdir -p "$dir/catalog/moved-source"
  mv "$moved" "$dir/catalog/moved-source/agent.json"

  run_once "$id" "$host" source-move
  pid_live="$(wait_pid "$id" "$host" "$runtime_id")"
  generation_live="$(task_generation "$id" "$host" "$runtime_id")"
  case_env "$id" st2 ls --catalog "$dir/catalog" >"$dir/source-move.ls"
  grep -Fq "$dir/catalog/moved-source/agent.json" "$dir/source-move.ls"
  grep -Fq "command exec bash \"$dir/task.sh\" \"noop\" \"$dir/noop-count\"" "$dir/source-move.ls"
  grep -Fq "adopted (1): $identity" "$dir/source-move.out"
  assert_no_reconcile_action "$dir/source-move.out"
  test "$pid_live" = "$pid_before"
  test "$generation_live" = "$generation_before"
  test "$(cat "$dir/noop-count")" -eq 1
  test "$(message_count "$id" "$host.$identity")" -eq 0

  # A source-only semantic no-op must not suppress independent healing of the exact dead task.
  stop_exact_pid "$pid_before"
  run_once "$id" "$host" heal
  pid_after="$(wait_pid "$id" "$host" "$runtime_id")"
  generation_after="$(task_generation "$id" "$host" "$runtime_id")"
  test "$pid_after" != "$pid_before"
  test "$generation_after" != "$generation_before"
  test "$(cat "$dir/noop-count")" -eq 2
  test "$(message_count "$id" "$host.$identity")" -eq 0
}

probe_identity_remove_add() {
  id="identity-remove-add" host="fm02"
  initialize_case "$id"
  dir="$(case_dir "$id")"
  spec="$(write_single_exec "$id" "$host" old worker service "$dir/work-a" work "$host.old.work" old)"
  run_once "$id" "$host" old
  old_pid="$(wait_pid "$id" "$host" "$host.old.work")"
  rm -f "$spec"
  write_single_exec "$id" "$host" new worker service "$dir/work-a" work "$host.new.work" new >/dev/null
  run_once "$id" "$host" new
  wait_pid "$id" "$host" "$host.new.work" >/dev/null
  wait_dead "$old_pid"
}

host_projection_overlap() {
  old_id="host-projection/overlap/old"
  new_id="host-projection/overlap/new"
  identity="agent"
  initialize_case "$old_id"
  initialize_case "$new_id"
  old_dir="$(case_dir "$old_id")"
  new_dir="$(case_dir "$new_id")"
  old_spec="$(write_single_exec "$old_id" old "$identity" worker service "$old_dir/work-a" work - oldhost)"
  run_once "$old_id" old initial-old
  old_pid="$(wait_pid "$old_id" old "old.$identity.work")"
  test "$(PTY_ROOT="$new_dir/pty" pty list --json | jq 'length')" -eq 0

  # New projection arrives first: overlap is allowed, and neither host consults a shared receipt.
  write_single_exec "$new_id" new "$identity" worker service "$new_dir/work-a" work - newhost >/dev/null
  run_once "$new_id" new add-new
  new_pid="$(wait_pid "$new_id" new "new.$identity.work")"
  new_generation="$(task_generation "$new_id" new "new.$identity.work")"
  kill -0 "$old_pid"
  kill -0 "$new_pid"
  test "$old_dir/state" != "$new_dir/state"
  test "$old_dir/pty" != "$new_dir/pty"

  rm -f "$old_spec"
  run_once "$old_id" old converge-remove-old
  removed=0
  wait_dead "$old_pid" || removed=1
  new_after="$(wait_pid "$new_id" new "new.$identity.work")"
  new_generation_after="$(task_generation "$new_id" new "new.$identity.work")"
  test "$new_after" = "$new_pid"
  test "$new_generation_after" = "$new_generation"
  test "$removed" -eq 0
}

host_projection_absence() {
  old_id="host-projection/absence/old"
  new_id="host-projection/absence/new"
  identity="agent"
  initialize_case "$old_id"
  initialize_case "$new_id"
  old_dir="$(case_dir "$old_id")"
  new_dir="$(case_dir "$new_id")"
  old_spec="$(write_single_exec "$old_id" old "$identity" worker service "$old_dir/work-a" work - oldhost)"
  run_once "$old_id" old initial-old
  old_pid="$(wait_pid "$old_id" old "old.$identity.work")"

  # Old projection leaves first: temporary global absence is allowed before the new host catches up.
  rm -f "$old_spec"
  run_once "$old_id" old remove-old-first
  removed=0
  wait_dead "$old_pid" || removed=1
  new_absent="$(PTY_ROOT="$new_dir/pty" pty list --json | jq 'length')"

  write_single_exec "$new_id" new "$identity" worker service "$new_dir/work-a" work - newhost >/dev/null
  run_once "$new_id" new converge-add-new
  new_pid="$(wait_pid "$new_id" new "new.$identity.work")"
  test "$new_absent" -eq 0
  kill -0 "$new_pid"
  test "$old_dir/state" != "$new_dir/state"
  test "$old_dir/pty" != "$new_dir/pty"
  test "$removed" -eq 0
}

probe_host_projection() {
  id="host-projection"
  dir="$(case_dir "$id")"
  mkdir -p "$dir"
  overlap_rc=0
  absence_rc=0
  (set -euo pipefail; host_projection_overlap) >"$dir/overlap.log" 2>&1 || overlap_rc=$?
  (set -euo pipefail; host_projection_absence) >"$dir/absence.log" 2>&1 || absence_rc=$?
  printf 'overlap_rc=%s absence_rc=%s\n' "$overlap_rc" "$absence_rc"
  test "$overlap_rc" -eq 0
  test "$absence_rc" -eq 0
}

probe_invalid_type_refuses() {
  id="invalid-type-refuses" host="fm04"
  initialize_case "$id"
  dir="$(case_dir "$id")"
  write_single_exec "$id" "$host" agent worker invalid-f102 "$dir/work-a" work "$host.agent.work" invalid >/dev/null
  validate_rc=0
  validate_case "$id" "$host" validate || validate_rc=$?
  run_rc=0
  run_once "$id" "$host" reconcile || run_rc=$?
  test "$validate_rc" -ne 0
  test "$run_rc" -ne 0
  test -z "$(find "$dir/state" -type f -name '*.pid' -print -quit)"
  test ! -e "$dir/invalid-count"
}

probe_role_metadata_adopts() {
  id="role-metadata-adopts" host="fm05" identity="agent" runtime_id="$host.$identity.work"
  initialize_case "$id"
  dir="$(case_dir "$id")"
  spec="$(write_single_exec "$id" "$host" "$identity" worker service "$dir/work-a" work "$runtime_id" role)"
  run_once "$id" "$host" launch
  pid_before="$(wait_pid "$id" "$host" "$runtime_id")"
  generation_before="$(task_generation "$id" "$host" "$runtime_id")"
  role_before="$(case_env "$id" st2 agents --json --catalog "$dir/catalog" |
    jq -r --arg identity "$host.$identity" '.[] | select(.identity == $identity) | .role // "__missing__"')"
  sed -i 's/role "worker"/role "reviewer"/' "$spec"
  run_once "$id" "$host" role
  pid_after="$(wait_pid "$id" "$host" "$runtime_id")"
  generation_after="$(task_generation "$id" "$host" "$runtime_id")"
  role_after="$(case_env "$id" st2 agents --json --catalog "$dir/catalog" |
    jq -r --arg identity "$host.$identity" '.[] | select(.identity == $identity) | .role // "__missing__"')"
  test "$pid_after" = "$pid_before"
  test "$generation_after" = "$generation_before"
  test "$(cat "$dir/role-count")" -eq 1
  test "$(message_count "$id" "$host.$identity")" -eq 0
  grep -Fq "adopted (1): $identity" "$dir/role.out"
  assert_no_reconcile_action "$dir/role.out"
  test "$role_before" = worker
  test "$role_after" = reviewer
}

probe_workspace_survivor_event() {
  id="workspace-survivor-event" host="fm06" identity="agent" runtime_id="$host.$identity.work"
  initialize_case "$id"
  dir="$(case_dir "$id")"
  printf 'WORKSPACE_SECRET_OLD_F102\n' >"$dir/work-a/private.txt"
  printf 'WORKSPACE_SECRET_NEW_F102\n' >"$dir/work-b/private.txt"
  spec="$(write_single_exec "$id" "$host" "$identity" worker service "$dir/work-a" work "$runtime_id" workspace)"
  run_once "$id" "$host" launch
  pid_before="$(wait_pid "$id" "$host" "$runtime_id")"
  generation_before="$(task_generation "$id" "$host" "$runtime_id")"
  sed -i "s|workspace \"$dir/work-a\"|workspace \"$dir/work-b\"|" "$spec"
  run_once "$id" "$host" workspace
  pid_after="$(wait_pid "$id" "$host" "$runtime_id")"
  generation_after="$(task_generation "$id" "$host" "$runtime_id")"
  test "$pid_after" = "$pid_before"
  test "$generation_after" = "$generation_before"
  test "$(cat "$dir/workspace-count")" -eq 1
  case_env "$id" st2 ls --catalog "$dir/catalog" >"$dir/workspace.ls"
  visibility_rc=0
  grep -Fq "$dir/work-b" "$dir/workspace.ls" || visibility_rc=$?
  event_rc=0
  filename="$(capture_change_event "$id" "$host" "$identity" workspace "$dir/event.json" \
    "$dir/work-a" "$dir/work-b")" || event_rc=$?
  if test "$event_rc" -eq 0; then
    assert_event_omits "$dir/event.json" \
      WORKSPACE_SECRET_OLD_F102 WORKSPACE_SECRET_NEW_F102 || event_rc=$?
    if test "$event_rc" -eq 0; then
      archive_and_replay_event "$id" "$host" "$identity" "$filename" || event_rc=$?
    fi
  fi
  run_once "$id" "$host" unchanged
  test "$(message_count "$id" "$host.$identity")" -eq 0
  test "$(wait_pid "$id" "$host" "$runtime_id")" = "$pid_before"
  printf 'post-commit-visibility-rc=%s event-oracle-rc=%s\n' "$visibility_rc" "$event_rc"
  test "$visibility_rc" -eq 0
  test "$event_rc" -eq 0
}

probe_resource_survivor_event() {
  id="resource-survivor-event" host="fm07" identity="agent" runtime_id="$host.$identity.work"
  initialize_case "$id"
  dir="$(case_dir "$id")"
  spec="$(write_single_exec "$id" "$host" "$identity" worker service "$dir/work-a" work "$runtime_id" resource \
    '  resource "old-work" _tag="issue" uri="issue://field/old"')"
  run_once "$id" "$host" launch
  pid_before="$(wait_pid "$id" "$host" "$runtime_id")"
  generation_before="$(task_generation "$id" "$host" "$runtime_id")"
  sed -i 's|resource "old-work" _tag="issue" uri="issue://field/old"|resource "new-work" _tag="task" uri="task://field/new"|' "$spec"
  run_once "$id" "$host" resource
  pid_after="$(wait_pid "$id" "$host" "$runtime_id")"
  generation_after="$(task_generation "$id" "$host" "$runtime_id")"
  test "$pid_after" = "$pid_before"
  test "$generation_after" = "$generation_before"
  test "$(cat "$dir/resource-count")" -eq 1
  case_env "$id" st2 agents --json --catalog "$dir/catalog" |
    jq -e '.[] | select(.identity == "fm07.agent") |
      (.resources | length == 1) and
      (.resources[0] == {"name":"new-work","_tag":"task","uri":"task://field/new"})' >/dev/null
  event_rc=0
  filename="$(capture_change_event "$id" "$host" "$identity" resource "$dir/event.json" \
    old-work new-work issue://field/old task://field/new)" || event_rc=$?
  if test "$event_rc" -eq 0; then
    assert_event_omits "$dir/event.json" RESOURCE_SECRET_F102 || event_rc=$?
    if test "$event_rc" -eq 0; then
      archive_and_replay_event "$id" "$host" "$identity" "$filename" || event_rc=$?
    fi
  fi
  run_once "$id" "$host" unchanged
  test "$(message_count "$id" "$host.$identity")" -eq 0
  test "$(wait_pid "$id" "$host" "$runtime_id")" = "$pid_before"
  printf 'event-oracle-rc=%s\n' "$event_rc"
  test "$event_rc" -eq 0
}

probe_render_survivor_event() {
  id="render-survivor-event" host="fm08" identity="agent" runtime_id="$host.$identity.work"
  initialize_case "$id"
  dir="$(case_dir "$id")"
  spec="$dir/catalog/agents/$host/$identity/agent.kdl"
  mkdir -p "$(dirname "$spec")"
  cat >"$spec" <<KDL
agent "$identity" {
  host "$host"
  role "worker"
  type "service"
  workspace "$dir/work-a"
  render {
    file "context-a.txt" "RENDER_SECRET_A_OLD_F102"
    file "context-b.txt" "RENDER_SECRET_B_OLD_F102"
  }
  exec "work" {
    id "$runtime_id"
    command "exec bash \"$dir/task.sh\" \"render\" \"$dir/render-count\""
  }
}
KDL
  run_once "$id" "$host" launch
  pid_before="$(wait_pid "$id" "$host" "$runtime_id")"
  generation_before="$(task_generation "$id" "$host" "$runtime_id")"
  test "$(cat "$dir/work-a/context-a.txt")" = RENDER_SECRET_A_OLD_F102
  test "$(cat "$dir/work-a/context-b.txt")" = RENDER_SECRET_B_OLD_F102
  sed -i 's/RENDER_SECRET_A_OLD_F102/RENDER_SECRET_A_NEW_F102/; s/RENDER_SECRET_B_OLD_F102/RENDER_SECRET_B_NEW_F102/' "$spec"
  run_once "$id" "$host" render
  pid_after="$(wait_pid "$id" "$host" "$runtime_id")"
  generation_after="$(task_generation "$id" "$host" "$runtime_id")"
  test "$pid_after" = "$pid_before"
  test "$generation_after" = "$generation_before"
  test "$(cat "$dir/render-count")" -eq 1
  test "$(cat "$dir/work-a/context-a.txt")" = RENDER_SECRET_A_NEW_F102
  test "$(cat "$dir/work-a/context-b.txt")" = RENDER_SECRET_B_NEW_F102
  event_rc=0
  filename="$(capture_change_event "$id" "$host" "$identity" render "$dir/event.json" \
    "$dir/work-a/context-a.txt" "$dir/work-a/context-b.txt")" || event_rc=$?
  if test "$event_rc" -eq 0; then
    assert_event_omits "$dir/event.json" \
      RENDER_SECRET_A_OLD_F102 RENDER_SECRET_B_OLD_F102 \
      RENDER_SECRET_A_NEW_F102 RENDER_SECRET_B_NEW_F102 || event_rc=$?
    if test "$event_rc" -eq 0; then
      archive_and_replay_event "$id" "$host" "$identity" "$filename" || event_rc=$?
    fi
  fi
  run_once "$id" "$host" unchanged
  test "$(message_count "$id" "$host.$identity")" -eq 0
  test "$(wait_pid "$id" "$host" "$runtime_id")" = "$pid_before"
  printf 'event-oracle-rc=%s\n' "$event_rc"
  test "$event_rc" -eq 0
}

probe_task_set_remove() {
  id="task-set-remove" host="fm09" identity="agent"
  initialize_case "$id"
  dir="$(case_dir "$id")"
  write_two_exec "$id" "$host" "$identity" "$dir/work-a" removed "$host.$identity.removed" removed keep "$host.$identity.keep" keep >/dev/null
  run_once "$id" "$host" launch
  removed_pid="$(wait_pid "$id" "$host" "$host.$identity.removed")"
  keep_pid="$(wait_pid "$id" "$host" "$host.$identity.keep")"
  write_two_exec "$id" "$host" "$identity" "$dir/work-a" - - - keep "$host.$identity.keep" keep >/dev/null
  run_once "$id" "$host" remove
  keep_after="$(wait_pid "$id" "$host" "$host.$identity.keep")"
  test "$keep_after" = "$keep_pid"
  wait_dead "$removed_pid"
}

probe_task_id_change() {
  id="task-id-change" host="fm10" identity="agent"
  initialize_case "$id"
  dir="$(case_dir "$id")"
  write_single_exec "$id" "$host" "$identity" worker service "$dir/work-a" old "$host.$identity.old" old >/dev/null
  run_once "$id" "$host" old
  old_pid="$(wait_pid "$id" "$host" "$host.$identity.old")"
  write_single_exec "$id" "$host" "$identity" worker service "$dir/work-a" new "$host.$identity.new" new >/dev/null
  run_once "$id" "$host" new
  wait_pid "$id" "$host" "$host.$identity.new" >/dev/null
  wait_dead "$old_pid"
}

probe_spawn_drift_visible() {
  id="spawn-drift-visible" host="fm11" identity="agent" runtime_id="$host.$identity.work"
  initialize_case "$id"
  dir="$(case_dir "$id")"
  spec="$(write_single_exec "$id" "$host" "$identity" worker service "$dir/work-a" work "$runtime_id" generation-a)"
  run_once "$id" "$host" launch
  pid_before="$(wait_pid "$id" "$host" "$runtime_id")"
  sed -i 's/generation-a/generation-b/g' "$spec"
  run_once "$id" "$host" drift
  pid_after="$(wait_pid "$id" "$host" "$runtime_id")"
  test "$pid_after" = "$pid_before"
  inventory="$(tasks_json "$id" "$host")"
  printf '%s\n' "$inventory" | jq -e --arg runtime_id "$runtime_id" '
    .tasks[] | select(.runtimeId == $runtime_id) |
    (.runtime.state == "drifted" or .runtime.state == "unknown") and
    (.desiredFingerprint | type == "string" and length > 0) and
    (.observedFingerprint | type == "string" and length > 0) and
    (.desiredFingerprint != .observedFingerprint)
  ' >/dev/null
}

probe_invalid_policy_refuses() {
  id="invalid-policy-refuses" host="fm12"
  initialize_case "$id"
  dir="$(case_dir "$id")"
  write_single_exec "$id" "$host" agent worker service "$dir/work-a" work "$host.agent.work" policy \
    $'  restart {\n    mode "invalid-f102"\n  }' >/dev/null
  if validate_case "$id" "$host" validate; then
    return 1
  fi
  test -z "$(find "$dir/state" -type f -name '*.pid' -print -quit)"
}

probe_retire_removed_child() {
  id="retire-removed-child" host="fm13" identity="agent"
  initialize_case "$id"
  dir="$(case_dir "$id")"
  write_two_exec "$id" "$host" "$identity" "$dir/work-a" removed "$host.$identity.removed" removed keep "$host.$identity.keep" keep >/dev/null
  run_once "$id" "$host" launch
  removed_pid="$(wait_pid "$id" "$host" "$host.$identity.removed")"
  keep_pid="$(wait_pid "$id" "$host" "$host.$identity.keep")"
  write_two_exec "$id" "$host" "$identity" "$dir/work-a" - - - keep "$host.$identity.keep" keep true >/dev/null
  run_once "$id" "$host" retire
  wait_dead "$keep_pid"
  wait_dead "$removed_pid"
}

run_compact_lowering_arm() {
  arm="$1"
  id="compact-lowering-equal/$arm"
  host="fm14"
  identity="agent"
  base="$(case_dir compact-lowering-equal)"
  dir="$(case_dir "$id")"
  workspace="$base/work-a"
  initialize_case "$id"
  mkdir -p "$workspace" "$dir/catalog/agents/$host/$identity"
  spec="$dir/catalog/agents/$host/$identity/agent.kdl"
  if test "$arm" = compact; then
    cat >"$spec" <<KDL
agent "$identity" {
  host "$host"
  role "worker"
  type "service"
  workspace "$workspace"
  env {
    F14_VALUE "equal-f102"
  }
  argv "bash" "$base/f14-agent.sh" "argument with space"
  lifecycle "service"
  ding
}
KDL
  else
    cat >"$spec" <<KDL
agent "$identity" {
  host "$host"
  role "worker"
  type "service"
  workspace "$workspace"
  env {
    F14_VALUE "equal-f102"
  }
  pty "agent" {
    id "$host.$identity"
    argv "bash" "$base/f14-agent.sh" "argument with space"
    lifecycle "service"
    tags role="agent"
  }
  ding
}
KDL
  fi

  rm -f "$workspace/launch.tsv" "$workspace/ding.txt"
  run_once "$id" "$host" launch
  wait_file "$workspace/launch.tsv"
  agent_pid="$(wait_pid "$id" "$host" "$host.$identity")"
  ding_pid="$(wait_pid "$id" "$host" "$host.$identity.ding")"
  kill -0 "$agent_pid"
  kill -0 "$ding_pid"
  cp "$workspace/launch.tsv" "$base/$arm.launch.tsv"
  tasks_json "$id" "$host" |
    jq -S '[.tasks[] | {agent,task,runtimeId,kind,lifecycle,retired,desiredState}]' >"$base/$arm.tasks.json"
  case_env "$id" st2 ls --catalog "$dir/catalog" |
    grep '^      - ' >"$base/$arm.lowering.txt"
  PTY_ROOT="$dir/pty" pty list --json |
    jq -S --arg runtime_id "$host.$identity" \
      '[.[] | select(.name == $runtime_id) | {command,cwd}]' >"$base/$arm.pty-launch.json"
  tr '\0' '\n' <"/proc/$ding_pid/environ" | grep '^F14_VALUE=' >"$base/$arm.ding-env.txt"

  case_env "$id" st2 message send "$host.$identity" --as "$host.sender" \
    --subject "F14 lowering" -m "same lowering payload" >/dev/null
  wait_file "$workspace/ding.txt"
  sed -E 's/\[id:[0-9a-z]{6}\]/[id:STABLE]/' "$workspace/ding.txt" >"$base/$arm.ding.txt"
  cleanup_case "$id"
}

probe_compact_lowering_equal() {
  id="compact-lowering-equal"
  dir="$(case_dir "$id")"
  mkdir -p "$dir/work-a"
  cat >"$dir/f14-agent.sh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
{
  printf 'script=%s\n' "$0"
  printf 'arg=%s\n' "${1:-}"
  printf 'env=%s\n' "${F14_VALUE:-}"
  printf 'cwd=%s\n' "$PWD"
} >"$PWD/launch.tsv"
while IFS= read -r line; do
  printf '%s\n' "$line" >>"$PWD/ding.txt"
done
SH
  chmod +x "$dir/f14-agent.sh"

  run_compact_lowering_arm compact
  run_compact_lowering_arm explicit
  id="compact-lowering-equal"
  dir="$(case_dir "$id")"
  for surface in launch.tsv tasks.json lowering.txt pty-launch.json ding-env.txt ding.txt; do
    same_file_contents "$dir/compact.$surface" "$dir/explicit.$surface"
  done
  test "$(jq 'length' "$dir/compact.tasks.json")" -eq 2
  grep -Fq $'arg=argument with space' "$dir/compact.launch.tsv"
  grep -Fq $'env=equal-f102' "$dir/compact.launch.tsv"
  grep -Fq "cwd=$dir/work-a" "$dir/compact.launch.tsv"
  grep -Fq '[DING] new st2 message: [id:STABLE] F14 lowering (from fm14.sender); check your inbox' \
    "$dir/compact.ding.txt"
}

probe_provider_fields_core_noop() {
  id="provider-fields-core-noop" host="fm15" identity="agent" runtime_id="$host.$identity.work"
  initialize_case "$id"
  dir="$(case_dir "$id")"
  cat >"$dir/f15-task.sh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
{
  printf 'script=%s\n' "$0"
  printf 'arg=%s\n' "${1:-}"
  printf 'env=%s\n' "${F15_VALUE:-}"
  printf 'cwd=%s\n' "$PWD"
} >"$PWD/launch.tsv"
trap 'exit 0' TERM INT
while :; do sleep 1; done
SH
  chmod +x "$dir/f15-task.sh"
  spec="$dir/catalog/agents/$host/$identity/agent.kdl"
  mkdir -p "$(dirname "$spec")"
  cat >"$spec" <<KDL
agent "$identity" {
  host "$host"
  role "worker"
  type "service"
  workspace "$dir/work-a"
  harness "provider-a-harness"
  model "provider-a-model"
  persona "provider-a-persona"
  permissions "provider-a-permissions"
  transport "provider-a-transport"
  strategy "provider-a-strategy"
  meta { opaque "provider-a-meta" }
  exec "work" {
    id "$runtime_id"
    argv "bash" "$dir/f15-task.sh" "argument with space"
    env {
      F15_VALUE "stable-f102"
    }
  }
}
KDL

  run_once "$id" "$host" launch
  wait_file "$dir/work-a/launch.tsv"
  pid_before="$(wait_pid "$id" "$host" "$runtime_id")"
  generation_before="$(task_generation "$id" "$host" "$runtime_id")"
  process_before="$(process_generation_token "$pid_before")"
  fingerprint_before="$(sha256sum "$dir/work-a/launch.tsv" | awk '{print $1}')"
  tasks_json "$id" "$host" | jq -S . >"$dir/before.tasks.json"

  sed -i 's/provider-a/provider-b/g' "$spec"
  run_once "$id" "$host" provider-fields
  pid_after="$(wait_pid "$id" "$host" "$runtime_id")"
  generation_after="$(task_generation "$id" "$host" "$runtime_id")"
  process_after="$(process_generation_token "$pid_after")"
  fingerprint_after="$(sha256sum "$dir/work-a/launch.tsv" | awk '{print $1}')"
  tasks_json "$id" "$host" | jq -S . >"$dir/after.tasks.json"

  test "$pid_after" = "$pid_before"
  test "$generation_after" = "$generation_before"
  test "$process_after" = "$process_before"
  test "$fingerprint_after" = "$fingerprint_before"
  same_file_contents "$dir/before.tasks.json" "$dir/after.tasks.json"
  grep -Fq "adopted (1): $identity" "$dir/provider-fields.out"
  assert_no_reconcile_action "$dir/provider-fields.out"
  test "$(message_count "$id" "$host.$identity")" -eq 0
}

probe_invalid_agent_isolated() {
  id="invalid-agent-isolated" host="fm16"
  initialize_case "$id"
  dir="$(case_dir "$id")"
  held_spec="$(write_single_exec "$id" "$host" held worker service "$dir/work-a" work \
    "$host.held.work" held '' '    lifecycle "service"')"
  run_once "$id" "$host" initial-held
  held_pid="$(wait_pid "$id" "$host" "$host.held.work")"
  held_generation="$(task_generation "$id" "$host" "$host.held.work")"
  held_process="$(process_generation_token "$held_pid")"

  # Corrupt only the held agent and add one independently valid agent with a distinct runtime id.
  sed -i 's/lifecycle "service"/lifecycle "invalid-f102"/' "$held_spec"
  write_single_exec "$id" "$host" valid worker service "$dir/work-b" work \
    "$host.valid.work" valid >/dev/null
  mixed_rc=0
  run_once "$id" "$host" mixed || mixed_rc=$?
  valid_pid="$(wait_pid "$id" "$host" "$host.valid.work")"

  kill -0 "$held_pid"
  test "$(process_generation_token "$held_pid")" = "$held_process"
  test "$(cat "$dir/held-count")" -eq 1
  test "$(cat "$dir/valid-count")" -eq 1
  test "$host.held.work" != "$host.valid.work"
  kill -0 "$valid_pid"
  grep -Fq "unknown lifecycle 'invalid-f102'" "$dir/mixed.err"
  grep -Fq "$host.valid.work" "$dir/mixed.out"
  test "$(message_count "$id" "$host.held")" -eq 0
  test "$(message_count "$id" "$host.valid")" -eq 0
  printf 'partial-run-exit=%s held-generation=%s\n' "$mixed_rc" "$held_generation" >"$dir/isolation-receipt.txt"
}

probe_plan_dry_run_order() {
  id="plan-dry-run-order" host="fm17"
  initialize_case "$id"
  dir="$(case_dir "$id")"
  write_single_exec "$id" "$host" agent worker service "$dir/work-a" work "$host.agent.work" dry >/dev/null
  st2 up --help | grep -Fq -- '--dry-run'
  case_env "$id" st2 up --dry-run --catalog "$dir/catalog" --host "$host" >"$dir/dry-run.out"
  test -z "$(find "$dir/state" -type f -name '*.pid' -print -quit)"
  awk '
    /FENCE/ { if (phase < 1) phase=1 }
    /REMOVE\/QUIESCE/ { if (phase == 1) phase=2 }
    /MATERIALIZE/ { if (phase == 2) phase=3 }
    /ADD\/BOOT/ { if (phase == 3) phase=4 }
    /NOTIFY/ { if (phase == 4) phase=5 }
    /VERIFY\/REPORT/ { if (phase == 5) phase=6 }
    END { exit phase == 6 ? 0 : 1 }
  ' "$dir/dry-run.out"
}

probe_moved_intent_refusal() {
  id="moved-intent-refusal" host="fm18"
  initialize_case "$id"
  dir="$(case_dir "$id")"
  spec="$(write_single_exec "$id" "$host" agent worker service "$dir/work-a" work "$host.agent.work" moved \
    $'  moved {\n    from "fm18.agent"\n    to "fm18.agent"\n  }')"
  if validate_case "$id" "$host" validate; then
    return 1
  fi
  test -f "$spec"
  test -z "$(find "$dir/state" -type f -name '*.pid' -print -quit)"
}

cleanup_all() {
  live_exec=0
  live_pty=0
  live_process=0

  while IFS= read -r pid_file; do
    pid="$(cat "$pid_file" 2>/dev/null || true)"
    case "$pid" in
      ''|*[!0-9]*) continue ;;
    esac
    if kill -0 "$pid" 2>/dev/null; then
      stop_exact_pid "$pid" || true
    fi
  done < <(find "$cases_root" -type f -path '*/state/st2/*/exec/*.pid' -print 2>/dev/null)

  while IFS= read -r pty_root; do
    while IFS= read -r name; do
      test -n "$name" || continue
      PTY_ROOT="$pty_root" pty kill "$name" >/dev/null 2>&1 || true
      PTY_ROOT="$pty_root" pty rm "$name" >/dev/null 2>&1 || true
    done < <(PTY_ROOT="$pty_root" pty list --json 2>/dev/null | jq -r '.[].name' 2>/dev/null || true)
  done < <(find "$cases_root" -type d -name pty -print 2>/dev/null)

  while IFS= read -r pid_file; do
    pid="$(cat "$pid_file" 2>/dev/null || true)"
    case "$pid" in
      ''|*[!0-9]*) continue ;;
    esac
    if kill -0 "$pid" 2>/dev/null; then
      live_exec=$((live_exec + 1))
      live_process=$((live_process + 1))
    fi
  done < <(find "$cases_root" -type f -path '*/state/st2/*/exec/*.pid' -print 2>/dev/null)

  while IFS= read -r pty_root; do
    count="$(PTY_ROOT="$pty_root" pty list --json 2>/dev/null | jq 'length' 2>/dev/null || printf '0\n')"
    live_pty=$((live_pty + count))
    live_process=$((live_process + count))
  done < <(find "$cases_root" -type d -name pty -print 2>/dev/null)

  if test "$live_exec" -eq 0 && test "$live_pty" -eq 0 && test "$live_process" -eq 0; then
    printf 'ZERO-RESIDUE\texec=0\tpty=0\tprocess=0\tcatalogs=18\n'
    return 0
  fi
  printf 'RESIDUE\texec=%s\tpty=%s\tprocess=%s\n' "$live_exec" "$live_pty" "$live_process"
  return 1
}

probe_name() {
  printf 'probe_%s\n' "$(printf '%s' "$1" | tr '-' '_')"
}

pass_count=0
red_count=0
unexpected=0

while IFS=$'\t' read -r case_id fields expected gaps contract; do
  test "$case_id" != case_id || continue
  probe="$(probe_name "$case_id")"
  log="$(case_dir "$case_id")/probe.log"
  mkdir -p "$(dirname "$log")"
  (
    set -euo pipefail
    "$probe"
  ) >"$log" 2>&1
  rc=$?
  if test "$rc" -eq 0; then
    observed=PASS
    pass_count=$((pass_count + 1))
  else
    observed=RED
    red_count=$((red_count + 1))
  fi
  test "$observed" = "$expected" || unexpected=$((unexpected + 1))
  printf 'RESULT\t%s\t%s\t%s\t%s\t%s\trc=%s log=cases/%s/probe.log\n' \
    "$case_id" "$fields" "$expected" "$gaps" "$observed" "$rc" "$case_id"
done <"$manifest"

printf 'SUMMARY\tconformance-pass=%s\texpected-red=%s\tunexpected=%s\n' \
  "$pass_count" "$red_count" "$unexpected"

cleanup_rc=0
cleanup_all || cleanup_rc=$?

# This is a contract conformance step, not a gap-classification step. Keep it
# red while any product case is red, even when every red is expected and mapped.
test "$unexpected" -eq 0 || exit 2
test "$cleanup_rc" -eq 0 || exit 3
test "$red_count" -eq 0
