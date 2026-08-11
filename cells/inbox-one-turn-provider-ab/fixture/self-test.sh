#!/usr/bin/env bash
set -euo pipefail

fixture="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
scratch="$(mktemp -d)"
cleanup() { rm -rf -- "$scratch"; }
trap cleanup EXIT

mkdir -p "$scratch"/{bin,metrics,scenario,requester/inbox,requester/archive}
mkdir -p "$scratch/agents/iot/injector/resources"/{inbox,archive}
cp "$fixture/bin/st2" "$scratch/bin/st2"
for agent in iot.claude iot.codex; do
  agent_dir="$scratch/agents/iot/${agent#iot.}/resources"
  mkdir -p "$agent_dir"/{inbox,archive}
  : >"$scratch/metrics/$agent.jsonl"
  index=0
  for token in \
    IOT-COLD-A-4d91 IOT-COLD-B-7a2c IOT-BURST-1-31ef \
    IOT-BURST-2-82bc IOT-BURST-3-c540 IOT-POST-BATCH-f92a; do
    index=$((index + 1))
    name="$(printf '%03d-%s.md' "$index" "$agent")"
    printf '%s\n' "$token" >"$agent_dir/archive/$name"
    {
      printf 'from: %s\n' "$agent"
      printf 'in-reply-to: %s\n\n' "$name"
      printf 'ACK %s\n' "$token"
    } >"$scratch/agents/iot/injector/resources/inbox/reply-$name"
  done
  if [ "$agent" = "iot.claude" ]; then
    jq -cn --arg at_ns "0" --argjson argv '["message","delivery","iot.claude"]' \
      '{at_ns:$at_ns,cwd:"/fixture",argv:$argv}' >>"$scratch/metrics/$agent.jsonl"
  fi
  jq -cn --arg at_ns "1" --argjson argv '["message","ls","'$agent'","--json","--include-body"]' \
    '{at_ns:$at_ns,cwd:"/fixture",argv:$argv}' >>"$scratch/metrics/$agent.jsonl"
  jq -cn --arg at_ns "2" --argjson argv '["message","reply","001.md","-m","ACK"]' \
    '{at_ns:$at_ns,cwd:"/fixture",argv:$argv}' >>"$scratch/metrics/$agent.jsonl"
  jq -cn --arg at_ns "3" --argjson argv '["message","archive","001.md"]' \
    '{at_ns:$at_ns,cwd:"/fixture",argv:$argv}' >>"$scratch/metrics/$agent.jsonl"
  printf '1\tfirst-batch-archived\t%s\n2\tpost-batch-sent\t%s\n' "$agent" "$agent" >>"$scratch/scenario/events.tsv"
done

CATALOG="$scratch" ST_ROOT="$scratch" bash "$fixture/judges/outcomes.sh" >/dev/null
CATALOG="$scratch" ST_ROOT="$scratch" ST2_REAL_BIN=/run/current-system/sw/bin/true PATH="$scratch/bin:$PATH" \
  bash "$fixture/judges/measurements.sh" | jq -e '
    .schema == "inbox-one-turn-provider-ab/v1" and
    (.subjects | length) == 2 and
    all(.subjects[]; (.archive_filenames | length) == 6) and
    ([.subjects[] | select(.agent == "iot.claude")][0] |
      .cli_processes == 4 and .provider_delivery_cli_processes == 1 and
      .first_subject_inbox_operation == "message ls") and
    ([.subjects[] | select(.agent == "iot.codex")][0] |
      .cli_processes == 3 and .provider_delivery_cli_processes == 0 and
      .first_subject_inbox_operation == "message ls")
  ' >/dev/null
echo "PASS: one-turn provider A/B held-out graders accept the complete synthetic control"
