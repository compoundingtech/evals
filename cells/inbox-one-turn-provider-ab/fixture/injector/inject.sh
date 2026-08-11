#!/usr/bin/env bash
set -euo pipefail

root="${CATALOG:?CATALOG must be set}"
bus="${ST_ROOT:-$root}"
state="$root/scenario"
mkdir -p "$state"

wait_for_subject_cli() {
  local agent="$1" file="$root/metrics/$1.jsonl"
  for _ in $(seq 1 1200); do
    if [ -s "$file" ] && jq -e -s '
      any(.[]; .argv[0] == "message" and .argv[1] != "delivery")
    ' "$file" >/dev/null 2>&1; then
      return 0
    fi
    sleep 0.25
  done
  echo "timed out waiting for $agent first subject inbox CLI process" >&2
  return 1
}

wait_for_archives() {
  local agent="$1"
  for _ in $(seq 1 1200); do
    if [ "$(archive_token_count "$agent")" -eq 5 ]; then
      return 0
    fi
    sleep 0.25
  done
  echo "timed out waiting for $agent first five archives" >&2
  return 1
}

archive_token_count() {
  local agent="$1"
  grep -lRE 'IOT-(COLD-[AB]|BURST-[123])-' "$bus/$agent/archive" 2>/dev/null | wc -l | tr -d ' '
}

send() {
  local target="$1" subject="$2" token="$3"
  st2 message send "$target" --as iot.injector --subject "$subject" \
    -m "Reply on this thread with exactly \`ACK $token\`, then archive this message." >/dev/null
}

for agent in iot.claude iot.codex; do
  wait_for_subject_cli "$agent"
  printf '%s\tfirst-subject-cli\t%s\n' "$(date +%s%N)" "$agent" >>"$state/events.tsv"
  send "$agent" "bounded burst 1" IOT-BURST-1-31ef
  send "$agent" "bounded burst 2" IOT-BURST-2-82bc
  send "$agent" "bounded burst 3" IOT-BURST-3-c540
  printf '%s\tburst-sent\t%s\n' "$(date +%s%N)" "$agent" >>"$state/events.tsv"
done

for agent in iot.claude iot.codex; do
  wait_for_archives "$agent"
  printf '%s\tfirst-batch-archived\t%s\n' "$(date +%s%N)" "$agent" >>"$state/events.tsv"
  send "$agent" "post-batch durability" IOT-POST-BATCH-f92a
  printf '%s\tpost-batch-sent\t%s\n' "$(date +%s%N)" "$agent" >>"$state/events.tsv"
done
