#!/usr/bin/env bash
set -euo pipefail

root="${CATALOG:?CATALOG must be set}"
bus="${ST_ROOT:-$root}"
wrapper="$(readlink -f "$root/bin/st2")"
real="${ST2_REAL_BIN:-}"
if [ -z "$real" ]; then
  while IFS= read -r candidate; do
    if [ "$(readlink -f "$candidate")" != "$wrapper" ]; then
      real="$candidate"
      break
    fi
  done < <(PATH="$root/bin:$PATH" type -a -P st2)
fi
[ -n "$real" ]

subjects='[]'
for agent in iot.claude iot.codex; do
  log="$root/metrics/$agent.jsonl"
  [ -s "$log" ]
  jq -s -e 'all(.[]; (.at_ns | test("^[0-9]+$")) and (.argv | type == "array"))' "$log" >/dev/null
  archive_names="$(find "$bus/$agent/archive" -maxdepth 1 -type f -printf '%f\n' | LC_ALL=C sort | jq -Rsc 'split("\n")[:-1]')"
  subject="$(jq -sc --arg agent "$agent" --argjson archives "$archive_names" '
    def is_delivery: .argv[0:2] == ["message", "delivery"];
    def is_discovery: .argv[0:2] == ["message", "ls"] or .argv[0:2] == ["message", "read"];
    def is_mutation: .argv[0:2] == ["message", "reply"] or .argv[0:2] == ["message", "archive"];
    {
      agent: $agent,
      cli_processes: length,
      provider_delivery_cli_processes: ([.[] | select(is_delivery)] | length),
      subject_inbox_cli_processes: ([.[] | select((.argv[0] == "message") and (is_delivery | not))] | length),
      discovery_cli_processes: ([.[] | select(is_discovery)] | length),
      mutation_cli_processes: ([.[] | select(is_mutation)] | length),
      first_subject_inbox_operation: ([.[] | select((.argv[0] == "message") and (is_delivery | not))][0].argv[0:2] | join(" ")),
      argv_bytes: ([.[] | (.argv | join(" ") | length)] | add),
      first_cli_at_ns: .[0].at_ns,
      last_cli_at_ns: .[-1].at_ns,
      archive_filenames: $archives,
      cli: .
    }
  ' "$log")"
  subjects="$(jq -cn --argjson all "$subjects" --argjson one "$subject" '$all + [$one]')"
done

source_payload_bytes="$(find "$bus/iot.claude/archive" -maxdepth 1 -type f -print0 | xargs -0 wc -c | awk 'END {print $1}')"
jq -cn \
  --arg runner_version "$("$real" --version)" \
  --arg runner_binary_sha256 "$(sha256sum "$real" | awk '{print $1}')" \
  --argjson source_payload_bytes "$source_payload_bytes" \
  --argjson subjects "$subjects" \
  --rawfile scenario "$root/scenario/events.tsv" \
  '{
    schema: "inbox-one-turn-provider-ab/v1",
    runner: {version: $runner_version, binary_sha256: $runner_binary_sha256},
    source_payload_bytes: $source_payload_bytes,
    subjects: $subjects,
    scenario_events_tsv: $scenario,
    provider_metrics_required_in_run_receipt: [
      "model_api_calls", "input_tokens", "output_tokens", "cache_tokens",
      "tool_call_boundaries", "total_prompt_bytes", "wall_time_seconds",
      "evals_source_commit", "st2_source_commit", "cleanup"
    ]
  }'
