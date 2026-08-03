#!/usr/bin/env bash
set -euo pipefail

root="${CATALOG:?CATALOG must be set}"
template="$root/adapter.sh"
red_count=0
pass_count=0
declare -a scenario_roots=()
declare -a launched_pids=()

uuid_for() {
  value="$1"
  hex="$(printf '%s' "$value" | sha256sum | cut -c1-32)"
  printf '%s-%s-4%s-a%s-%s\n' \
    "${hex:0:8}" "${hex:8:4}" "${hex:13:3}" "${hex:17:3}" "${hex:20:12}"
}

emit_pass() {
  printf 'CASE\t%s\tPASS\t-\t%s\n' "$1" "$2"
  ((pass_count += 1))
}

emit_red() {
  printf 'CASE\t%s\tRED\t%s\t%s\n' "$1" "$2" "$3"
  ((red_count += 1))
}

pty_at() {
  scenario="$1"
  shift
  env -u PTY_SESSION PTY_ROOT="$scenario/pty" pty "$@"
}

conversation_count() {
  file="$1"
  if [ ! -f "$file" ]; then
    printf '0\n'
    return
  fi
  jq -r 'select(.type == "conversation") | .sessionId' "$file" | wc -l
}

conversation_ids_are() {
  file="$1"
  expected="$2"
  test -f "$file"
  test "$(jq -r 'select(.type == "conversation") | .sessionId' "$file" | sort -u)" = "$expected"
}

wait_for_receipt() {
  receipt="$1"
  for _ in $(seq 1 100); do
    test -s "$receipt" && return 0
    sleep 0.02
  done
  return 1
}

setup_scenario() {
  case_id="$1"
  scenario="$root/scenarios/$case_id"
  scenario_roots+=("$scenario")
  mkdir -p "$scenario/agents/lm/worker" "$scenario/workspace" "$scenario/sessions" "$scenario/state"
  cp "$template" "$scenario/adapter.sh"
  chmod +x "$scenario/adapter.sh"
  printf '%s\n' 'DURABLE-WORK-CONTINUES-8d31' > "$scenario/durable"

  exact="$(uuid_for "$scenario/exact")"
  neighbor="$(uuid_for "$scenario/neighbor")"
  printf '%s\n' "$exact" > "$scenario/exact-id"
  printf '%s\n' "$neighbor" > "$scenario/neighbor-id"
  printf '{"type":"conversation","sessionId":"%s","turn":"seed-exact"}\n' "$exact" \
    > "$scenario/sessions/$exact.jsonl"
  printf '{"type":"conversation","sessionId":"%s","turn":"seed-neighbor"}\n' "$neighbor" \
    > "$scenario/sessions/$neighbor.jsonl"
}

write_specs() {
  start="$root/scenarios/explicit-start-new-session"
  start_exact="$(<"$start/exact-id")"
  cat > "$start/agents/lm/worker/agent.kdl" <<KDL
agent "worker" {
  host "lm"
  workspace "$start/workspace"
  start {
    argv "bash" "$start/adapter.sh" "start" "$start/sessions" "$start/durable" "$start/launch.tsv"
  }
  resume {
    session "$start_exact"
    argv "bash" "$start/adapter.sh" "resume" "$start/sessions" "$start/durable" "$start/launch.tsv" "$start_exact"
  }
  launch { default "start" }
}
KDL

  resume="$root/scenarios/explicit-resume-exact"
  resume_exact="$(<"$resume/exact-id")"
  cat > "$resume/agents/lm/worker/agent.kdl" <<KDL
agent "worker" {
  host "lm"
  workspace "$resume/workspace"
  start {
    argv "bash" "$resume/adapter.sh" "start" "$resume/sessions" "$resume/durable" "$resume/launch.tsv"
  }
  resume {
    session "$resume_exact"
    argv "bash" "$resume/adapter.sh" "resume" "$resume/sessions" "$resume/durable" "$resume/launch.tsv" "$resume_exact"
  }
  launch { default "resume" }
}
KDL

  refuse="$root/scenarios/unavailable-refuse"
  cat > "$refuse/agents/lm/worker/agent.kdl" <<KDL
agent "worker" {
  host "lm"
  workspace "$refuse/workspace"
  start {
    argv "bash" "$refuse/adapter.sh" "start" "$refuse/sessions" "$refuse/durable" "$refuse/launch.tsv"
  }
  launch { default "resume" }
}
KDL

  fallback="$root/scenarios/unavailable-start"
  cat > "$fallback/agents/lm/worker/agent.kdl" <<KDL
agent "worker" {
  host "lm"
  workspace "$fallback/workspace"
  start {
    argv "bash" "$fallback/adapter.sh" "start" "$fallback/sessions" "$fallback/durable" "$fallback/launch.tsv"
  }
  launch {
    default "resume"
    on-unavailable "start"
  }
}
KDL

  legacy="$root/scenarios/legacy-single-argv"
  cat > "$legacy/agents/lm/worker/agent.kdl" <<KDL
agent "worker" {
  host "lm"
  workspace "$legacy/workspace"
  argv "bash" "$legacy/adapter.sh" "legacy" "$legacy/sessions" "$legacy/durable" "$legacy/launch.tsv"
}
KDL
}

run_launch() {
  scenario="$1"
  export XDG_STATE_HOME="$scenario/state"
  PTY_ROOT="$scenario/pty" st2 up --once --catalog "$scenario" --host lm \
    > "$scenario/up.out" 2>&1
}

record_pid() {
  receipt="$1"
  pid="$(cut -f4 "$receipt")"
  test -n "$pid"
  launched_pids+=("$pid")
}

run_explicit_start() {
  scenario="$root/scenarios/explicit-start-new-session"
  exact="$(<"$scenario/exact-id")"
  neighbor="$(<"$scenario/neighbor-id")"
  if ! run_launch "$scenario" || ! wait_for_receipt "$scenario/launch.tsv"; then
    emit_red explicit-start-new-session P02 "start method was not selected"
    return
  fi
  record_pid "$scenario/launch.tsv"
  IFS=$'\t' read -r mode session durable _ < "$scenario/launch.tsv"
  if [ "$mode" != start ]; then
    emit_red explicit-start-new-session P02 "selected $mode instead of start"
  elif [ "$session" = "$exact" ] || [ "$session" = "$neighbor" ] || \
       ! conversation_ids_are "$scenario/sessions/$session.jsonl" "$session"; then
    emit_red explicit-start-new-session P03 "start did not create one new session"
  elif [ "$durable" != 'DURABLE-WORK-CONTINUES-8d31' ] || \
       [ "$(<"$scenario/durable")" != 'DURABLE-WORK-CONTINUES-8d31' ]; then
    emit_red explicit-start-new-session P05 "durable work did not continue"
  else
    emit_pass explicit-start-new-session "start created $session and preserved durable work"
  fi
}

run_explicit_resume() {
  scenario="$root/scenarios/explicit-resume-exact"
  exact="$(<"$scenario/exact-id")"
  neighbor="$(<"$scenario/neighbor-id")"
  exact_before="$(conversation_count "$scenario/sessions/$exact.jsonl")"
  neighbor_before="$(conversation_count "$scenario/sessions/$neighbor.jsonl")"
  if ! run_launch "$scenario" || ! wait_for_receipt "$scenario/launch.tsv"; then
    emit_red explicit-resume-exact P02 "resume method was not selected"
    return
  fi
  record_pid "$scenario/launch.tsv"
  IFS=$'\t' read -r mode session durable _ < "$scenario/launch.tsv"
  if [ "$mode" != resume ]; then
    emit_red explicit-resume-exact P02 "selected $mode instead of resume"
  elif [ "$session" != "$exact" ] || ! conversation_ids_are "$scenario/sessions/$exact.jsonl" "$exact" || \
       [ "$(conversation_count "$scenario/sessions/$exact.jsonl")" -ne $((exact_before + 1)) ] || \
       [ "$(conversation_count "$scenario/sessions/$neighbor.jsonl")" -ne "$neighbor_before" ] || \
       ! conversation_ids_are "$scenario/sessions/$neighbor.jsonl" "$neighbor"; then
    emit_red explicit-resume-exact P03 "resume did not continue only the declared session"
  elif [ "$durable" != 'DURABLE-WORK-CONTINUES-8d31' ]; then
    emit_red explicit-resume-exact P05 "durable work did not continue"
  else
    emit_pass explicit-resume-exact "resume appended only to $exact"
  fi
}

run_unavailable_refuse() {
  scenario="$root/scenarios/unavailable-refuse"
  exact="$(<"$scenario/exact-id")"
  neighbor="$(<"$scenario/neighbor-id")"
  exact_before="$(conversation_count "$scenario/sessions/$exact.jsonl")"
  neighbor_before="$(conversation_count "$scenario/sessions/$neighbor.jsonl")"
  if run_launch "$scenario"; then
    run_status=0
  else
    run_status=$?
  fi
  if [ -f "$scenario/launch.tsv" ] || \
     [ "$(conversation_count "$scenario/sessions/$exact.jsonl")" -ne "$exact_before" ] || \
     [ "$(conversation_count "$scenario/sessions/$neighbor.jsonl")" -ne "$neighbor_before" ]; then
    emit_red unavailable-refuse P04 "unavailable resume launched or mutated session state"
  elif [ "$run_status" -ne 0 ] && \
       grep -Fq "agent 'worker' default launch method 'resume' is unavailable and no declared \`on-unavailable\` method can be selected" \
         "$scenario/up.out"; then
    emit_pass unavailable-refuse "missing resume refused before launch"
  elif [ "$run_status" -eq 0 ] && \
       grep -Fq "agent 'worker' default launch method 'resume' is unavailable and no declared \`on-unavailable\` method can be selected" \
         "$scenario/up.out"; then
    emit_red unavailable-refuse P04 "missing resume reported an error but exited zero"
  else
    emit_red unavailable-refuse P04 "missing resume did not fail closed with the exact diagnostic"
  fi
}

run_unavailable_start() {
  scenario="$root/scenarios/unavailable-start"
  exact="$(<"$scenario/exact-id")"
  neighbor="$(<"$scenario/neighbor-id")"
  if ! run_launch "$scenario" || ! wait_for_receipt "$scenario/launch.tsv"; then
    emit_red unavailable-start P04 "declared start fallback was not selected"
    return
  fi
  record_pid "$scenario/launch.tsv"
  IFS=$'\t' read -r mode session durable _ < "$scenario/launch.tsv"
  if [ "$mode" != start ]; then
    emit_red unavailable-start P04 "selected $mode instead of start fallback"
  elif [ "$session" = "$exact" ] || [ "$session" = "$neighbor" ] || \
       ! conversation_ids_are "$scenario/sessions/$session.jsonl" "$session"; then
    emit_red unavailable-start P03 "fallback did not create a new session"
  elif [ "$durable" != 'DURABLE-WORK-CONTINUES-8d31' ]; then
    emit_red unavailable-start P05 "durable work did not continue"
  else
    emit_pass unavailable-start "unavailable resume selected start and created $session"
  fi
}

run_legacy() {
  scenario="$root/scenarios/legacy-single-argv"
  if ! st2 validate --catalog "$scenario" --host lm --strict > "$scenario/validate.out" 2>&1 || \
     ! run_launch "$scenario" || ! wait_for_receipt "$scenario/launch.tsv"; then
    emit_red legacy-single-argv P02 "legacy single argv no longer launches"
    return
  fi
  record_pid "$scenario/launch.tsv"
  IFS=$'\t' read -r mode session durable _ < "$scenario/launch.tsv"
  if [ "$mode" = legacy ] && [ "$session" = - ] && \
     [ "$durable" = 'DURABLE-WORK-CONTINUES-8d31' ]; then
    emit_pass legacy-single-argv "legacy single argv launched unchanged"
  else
    emit_red legacy-single-argv P02 "legacy argv selected an unexpected payload"
  fi
}

cleanup() {
  for scenario in "${scenario_roots[@]}"; do
    XDG_STATE_HOME="$scenario/state" PTY_ROOT="$scenario/pty" \
      st2 down --catalog "$scenario" --host lm >/dev/null 2>&1 || true
    while IFS= read -r id; do
      [ -n "$id" ] || continue
      pty_at "$scenario" kill "$id" >/dev/null 2>&1 || true
      pty_at "$scenario" rm "$id" >/dev/null 2>&1 || true
    done < <(pty_at "$scenario" list --json 2>/dev/null | jq -r '.[].name' || true)
  done
}
trap cleanup EXIT

for case_id in explicit-start-new-session explicit-resume-exact unavailable-refuse unavailable-start legacy-single-argv; do
  setup_scenario "$case_id"
done
write_specs

grammar="$root/scenarios/explicit-start-new-session"
if st2 validate --catalog "$grammar" --host lm --strict > "$grammar/validate.out" 2>&1; then
  run_explicit_start
  run_explicit_resume
  run_unavailable_refuse
  run_unavailable_start
else
  emit_red explicit-start-new-session P01 "proposed launch-method grammar is unavailable"
  emit_red explicit-resume-exact P01 "proposed launch-method grammar is unavailable"
  emit_red unavailable-refuse P01 "proposed launch-method grammar is unavailable"
  emit_red unavailable-start P01 "proposed launch-method grammar is unavailable"
fi
run_legacy

cleanup
trap - EXIT

live_pty=0
for scenario in "${scenario_roots[@]}"; do
  count="$(pty_at "$scenario" list --json 2>/dev/null | jq 'length' || printf '0')"
  live_pty=$((live_pty + count))
done

live_process=0
for pid in "${launched_pids[@]}"; do
  if kill -0 "$pid" 2>/dev/null; then
    live_process=$((live_process + 1))
  fi
done

printf 'SUMMARY pass=%d red=%d\n' "$pass_count" "$red_count"
if [ "$red_count" -gt 0 ]; then
  printf '%s\n' 'PRODUCT-RED launch-method-selection'
else
  printf '%s\n' 'PRODUCT-GREEN launch-method-selection'
fi
if [ "$live_pty" -eq 0 ] && [ "$live_process" -eq 0 ]; then
  printf '%s\n' 'ZERO-RESIDUE pty=0 process=0 catalogs=5'
fi

test "$red_count" -eq 0
