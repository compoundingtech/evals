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

stop_exact_pid() {
  pid="$1"
  case "$pid" in
    ''|*[!0-9]*) return 1 ;;
  esac
  kill -TERM -- "-$pid" 2>/dev/null || kill -TERM "$pid" 2>/dev/null || true
  wait_dead "$pid"
}

message_count() {
  id="$1"
  identity="$2"
  case_env "$id" st2 message ls "$identity" --json 2>/dev/null |
    jq 'length' 2>/dev/null || printf '0\n'
}

probe_source_noop_heals() {
  id="source-noop-heals" host="fm01" identity="agent" runtime_id="$host.$identity.work"
  initialize_case "$id"
  dir="$(case_dir "$id")"
  spec="$(write_single_exec "$id" "$host" "$identity" worker service "$dir/work-a" work "$runtime_id" noop)"
  case_env "$id" st2 up --catalog "$dir/catalog" --host "$host" --interval 30 \
    >"$dir/supervisor.out" 2>"$dir/supervisor.err" &
  supervisor_pid="$!"
  trap 'kill "$supervisor_pid" >/dev/null 2>&1 || true; wait "$supervisor_pid" >/dev/null 2>&1 || true' EXIT
  pid_before="$(wait_pid "$id" "$host" "$runtime_id")"
  adopted_before="$(grep -Fc 'adopted' "$dir/supervisor.out" 2>/dev/null || true)"
  printf '// live semantic source-only no-op\n' >>"$spec"
  sleep 1
  adopted_after="$(grep -Fc 'adopted' "$dir/supervisor.out" 2>/dev/null || true)"
  pid_live="$(wait_pid "$id" "$host" "$runtime_id")"
  stop_exact_pid "$pid_before"
  printf '// independently dead work may heal\n' >>"$spec"
  for _ in $(seq 1 100); do
    test -f "$dir/noop-count" && test "$(cat "$dir/noop-count")" -eq 2 && break
    sleep 0.05
  done
  pid_after="$(wait_pid "$id" "$host" "$runtime_id")"
  kill "$supervisor_pid" >/dev/null 2>&1 || true
  wait "$supervisor_pid" >/dev/null 2>&1 || true
  trap - EXIT
  test "$pid_live" = "$pid_before"
  test "$pid_after" != "$pid_before"
  test "$(cat "$dir/noop-count")" -eq 2
  test "$(message_count "$id" "$host.$identity")" -eq 0
  test "$adopted_after" -eq "$adopted_before"
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

probe_host_projection() {
  id="host-projection" identity="agent"
  initialize_case "$id"
  dir="$(case_dir "$id")"
  spec="$(write_single_exec "$id" old "$identity" worker service "$dir/work-a" work - oldhost)"
  run_once "$id" old old
  old_pid="$(wait_pid "$id" old "old.$identity.work")"
  rm -f "$spec"
  write_single_exec "$id" new "$identity" worker service "$dir/work-a" work - newhost >/dev/null
  run_once "$id" old remove-old
  run_once "$id" new add-new
  wait_pid "$id" new "new.$identity.work" >/dev/null
  wait_dead "$old_pid"
}

probe_invalid_type_refuses() {
  id="invalid-type-refuses" host="fm04"
  initialize_case "$id"
  dir="$(case_dir "$id")"
  write_single_exec "$id" "$host" agent worker invalid-f102 "$dir/work-a" work "$host.agent.work" invalid >/dev/null
  if validate_case "$id" "$host" validate; then
    return 1
  fi
  test -z "$(find "$dir/state" -type f -name '*.pid' -print -quit)"
}

probe_role_metadata_adopts() {
  id="role-metadata-adopts" host="fm05" identity="agent" runtime_id="$host.$identity.work"
  initialize_case "$id"
  dir="$(case_dir "$id")"
  spec="$(write_single_exec "$id" "$host" "$identity" worker service "$dir/work-a" work "$runtime_id" role)"
  run_once "$id" "$host" launch
  pid_before="$(wait_pid "$id" "$host" "$runtime_id")"
  sed -i 's/role "worker"/role "reviewer"/' "$spec"
  run_once "$id" "$host" role
  pid_after="$(wait_pid "$id" "$host" "$runtime_id")"
  test "$pid_after" = "$pid_before"
  test "$(message_count "$id" "$host.$identity")" -eq 0
}

probe_workspace_survivor_event() {
  id="workspace-survivor-event" host="fm06" identity="agent" runtime_id="$host.$identity.work"
  initialize_case "$id"
  dir="$(case_dir "$id")"
  spec="$(write_single_exec "$id" "$host" "$identity" worker service "$dir/work-a" work "$runtime_id" workspace)"
  run_once "$id" "$host" launch
  pid_before="$(wait_pid "$id" "$host" "$runtime_id")"
  sed -i "s|workspace \"$dir/work-a\"|workspace \"$dir/work-b\"|" "$spec"
  run_once "$id" "$host" workspace
  pid_after="$(wait_pid "$id" "$host" "$runtime_id")"
  test "$pid_after" = "$pid_before"
  test "$(message_count "$id" "$host.$identity")" -eq 1
}

probe_resource_survivor_event() {
  id="resource-survivor-event" host="fm07" identity="agent" runtime_id="$host.$identity.work"
  initialize_case "$id"
  dir="$(case_dir "$id")"
  spec="$(write_single_exec "$id" "$host" "$identity" worker service "$dir/work-a" work "$runtime_id" resource \
    '  resource "work" _tag="issue" uri="issue://field/old"')"
  run_once "$id" "$host" launch
  pid_before="$(wait_pid "$id" "$host" "$runtime_id")"
  sed -i 's|issue://field/old|issue://field/new|' "$spec"
  run_once "$id" "$host" resource
  pid_after="$(wait_pid "$id" "$host" "$runtime_id")"
  test "$pid_after" = "$pid_before"
  case_env "$id" st2 agents --json --catalog "$dir/catalog" |
    jq -e '.[] | select(.identity == "fm07.agent") | .resources[] | select(.uri == "issue://field/new")' >/dev/null
  test "$(message_count "$id" "$host.$identity")" -eq 1
}

probe_render_survivor_event() {
  id="render-survivor-event" host="fm08" identity="agent" runtime_id="$host.$identity.work"
  initialize_case "$id"
  dir="$(case_dir "$id")"
  spec="$(write_single_exec "$id" "$host" "$identity" worker service "$dir/work-a" work "$runtime_id" render \
    $'  render {\n    file "context.txt" "A-f102"\n  }')"
  run_once "$id" "$host" launch
  pid_before="$(wait_pid "$id" "$host" "$runtime_id")"
  test "$(cat "$dir/work-a/context.txt")" = A-f102
  sed -i 's/A-f102/B-f102/' "$spec"
  run_once "$id" "$host" render
  pid_after="$(wait_pid "$id" "$host" "$runtime_id")"
  test "$pid_after" = "$pid_before"
  test "$(cat "$dir/work-a/context.txt")" = B-f102
  test "$(message_count "$id" "$host.$identity")" -eq 1
  run_once "$id" "$host" unchanged
  test "$(message_count "$id" "$host.$identity")" -eq 1
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

probe_compact_lowering_equal() {
  id="compact-lowering-equal" host="fm14" identity="agent"
  initialize_case "$id"
  dir="$(case_dir "$id")"
  compact="$dir/catalog/compact/agents/$host/$identity/agent.kdl"
  explicit="$dir/catalog/explicit/agents/$host/$identity/agent.kdl"
  mkdir -p "$(dirname "$compact")" "$(dirname "$explicit")"
  cat >"$compact" <<KDL
agent "$identity" {
  host "$host"
  role "worker"
  type "service"
  workspace "$dir/work-a"
  command "sleep 30"
  ding
}
KDL
  cat >"$explicit" <<KDL
agent "$identity" {
  host "$host"
  role "worker"
  type "service"
  workspace "$dir/work-a"
  pty "agent" {
    id "$host.$identity"
    command "sleep 30"
  }
  exec "ding" {
    id "$host.$identity.ding"
    command "true"
  }
}
KDL
  CATALOG="$dir/catalog/compact" XDG_STATE_HOME="$dir/state/compact" PTY_ROOT="$dir/pty/compact" \
    st2 tasks --json --catalog "$dir/catalog/compact" --host "$host" |
    jq -S '[.tasks[] | {agent,task,runtimeId,kind,lifecycle,retired,desiredState}]' >"$dir/compact.json"
  CATALOG="$dir/catalog/explicit" XDG_STATE_HOME="$dir/state/explicit" PTY_ROOT="$dir/pty/explicit" \
    st2 tasks --json --catalog "$dir/catalog/explicit" --host "$host" |
    jq -S '[.tasks[] | {agent,task,runtimeId,kind,lifecycle,retired,desiredState}]' >"$dir/explicit.json"
  test "$(cat "$dir/compact.json")" = "$(cat "$dir/explicit.json")"
  test "$(jq 'length' "$dir/compact.json")" -eq 2
}

probe_provider_fields_core_noop() {
  id="provider-fields-core-noop" host="fm15" identity="agent"
  initialize_case "$id"
  dir="$(case_dir "$id")"
  for arm in base provider; do
    spec="$dir/catalog/$arm/agents/$host/$identity/agent.kdl"
    mkdir -p "$(dirname "$spec")"
    {
      printf 'agent "%s" {\n' "$identity"
      printf '  host "%s"\n' "$host"
      printf '  role "worker"\n'
      printf '  type "service"\n'
      printf '  workspace "%s"\n' "$dir/work-a"
      if test "$arm" = provider; then
        printf '  harness "codex"\n  model "provider-model"\n  persona "provider-persona"\n'
        printf '  permissions "provider-policy"\n  transport "provider-transport"\n'
        printf '  strategy "provider-strategy"\n  meta { opaque "value" }\n'
      fi
      printf '  exec "work" {\n'
      printf '    id "%s.%s.work"\n' "$host" "$identity"
      printf '    command "true"\n'
      printf '  }\n'
      printf '}\n'
    } >"$spec"
    CATALOG="$dir/catalog/$arm" XDG_STATE_HOME="$dir/state/$arm" PTY_ROOT="$dir/pty/$arm" \
      st2 validate --catalog "$dir/catalog/$arm" --host "$host" >"$dir/$arm.validate" 2>&1
    CATALOG="$dir/catalog/$arm" XDG_STATE_HOME="$dir/state/$arm" PTY_ROOT="$dir/pty/$arm" \
      st2 tasks --json --catalog "$dir/catalog/$arm" --host "$host" |
      jq -S '[.tasks[] | {agent,task,runtimeId,kind,lifecycle,retired,desiredState}]' >"$dir/$arm.tasks"
    CATALOG="$dir/catalog/$arm" XDG_STATE_HOME="$dir/state/$arm" PTY_ROOT="$dir/pty/$arm" \
      st2 agents --json --catalog "$dir/catalog/$arm" |
      jq -S '[.[] | {identity,retired,resources}]' >"$dir/$arm.agents"
  done
  test "$(cat "$dir/base.tasks")" = "$(cat "$dir/provider.tasks")"
  test "$(cat "$dir/base.agents")" = "$(cat "$dir/provider.agents")"
}

probe_invalid_agent_isolated() {
  id="invalid-agent-isolated" host="fm16"
  initialize_case "$id"
  dir="$(case_dir "$id")"
  write_single_exec "$id" "$host" valid worker service "$dir/work-a" work "$host.valid.work" valid >/dev/null
  write_single_exec "$id" "$host" invalid worker service "$dir/work-b" work "$host.valid.work" invalid >/dev/null
  set +e
  run_once "$id" "$host" mixed
  rc=$?
  set -e
  test "$rc" -ne 0
  wait_pid "$id" "$host" "$host.valid.work" >/dev/null
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
