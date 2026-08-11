#!/usr/bin/env bash
set -euo pipefail

root="${CATALOG:?CATALOG must be set}"
bus="${ST_ROOT:-$root}"
tokens=(
  IOT-COLD-A-4d91
  IOT-COLD-B-7a2c
  IOT-BURST-1-31ef
  IOT-BURST-2-82bc
  IOT-BURST-3-c540
  IOT-POST-BATCH-f92a
)

mailbox_dir() {
  printf '%s\n' "$bus/agents/iot/${1#iot.}"
}

for agent in iot.claude iot.codex; do
  agent_dir="$(mailbox_dir "$agent")"
  [ -d "$agent_dir/archive" ]
  [ "$(find "$agent_dir/inbox" -maxdepth 1 -type f | wc -l | tr -d ' ')" -eq 0 ]
  for token in "${tokens[@]}"; do
    [ "$(grep -lRF "$token" "$agent_dir/archive" 2>/dev/null | wc -l | tr -d ' ')" -eq 1 ]
    reply="$(
      grep -lRF "ACK $token" "$(mailbox_dir iot.injector)/inbox" "$(mailbox_dir iot.injector)/archive" 2>/dev/null |
        while IFS= read -r candidate; do
          if grep -Eq "^from:[[:space:]]*$agent([[:space:]]|$)" "$candidate"; then
            printf '%s\n' "$candidate"
            break
          fi
        done
    )"
    [ -n "$reply" ]
    grep -Fq 'in-reply-to:' "$reply"
    grep -Eq "^from:[[:space:]]*$agent([[:space:]]|$)" "$reply"
  done
  echo "PASS: $agent replied on and archived all six exact messages"
done

for agent in iot.claude iot.codex; do
  awk -F '\t' -v agent="$agent" '
    $2 == "first-batch-archived" && $3 == agent { archived = $1 }
    $2 == "post-batch-sent" && $3 == agent { sent = $1 }
    END { exit !(archived > 0 && sent > archived) }
  ' "$root/scenario/events.tsv"
done
echo "PASS: post-batch arrivals were created only after the bounded burst was durably archived"
