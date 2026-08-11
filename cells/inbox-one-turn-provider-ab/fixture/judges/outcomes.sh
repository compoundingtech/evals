#!/usr/bin/env bash
set -euo pipefail

root="${CATALOG:?CATALOG must be set}"
bus="${ST_ROOT:-$root}"
codex_tokens=(
  IOT-COLD-A-4d91
  IOT-COLD-B-7a2c
  IOT-BURST-1-31ef
  IOT-BURST-2-82bc
  IOT-BURST-3-c540
  IOT-POST-BATCH-f92a
)
claude_tokens=(IOT-COLD-A-4d91 IOT-COLD-B-7a2c)

mailbox_dir() {
  printf '%s\n' "$bus/agents/iot/${1#iot.}/resources"
}

for agent in iot.claude iot.codex; do
  if [ "$agent" = iot.claude ]; then
    tokens=("${claude_tokens[@]}")
  else
    tokens=("${codex_tokens[@]}")
  fi
  agent_dir="$(mailbox_dir "$agent")"
  [ -d "$agent_dir/archive" ]
  [ "$(find "$agent_dir/inbox" -maxdepth 1 -type f | wc -l | tr -d ' ')" -eq 0 ]
  for token in "${tokens[@]}"; do
    [ "$(grep -lRF "$token" "$agent_dir/archive" 2>/dev/null | wc -l | tr -d ' ')" -eq 1 ]
    reply=""
    mapfile -t candidates < <(
      grep -lRF "ACK $token" "$(mailbox_dir iot.injector)/inbox" \
        "$(mailbox_dir iot.injector)/archive" 2>/dev/null || true
    )
    for candidate in "${candidates[@]}"; do
      if grep -Eq "^from:[[:space:]]*$agent([[:space:]]|$)" "$candidate"; then
        reply="$candidate"
        break
      fi
    done
    [ -n "$reply" ]
    grep -Fq 'in-reply-to:' "$reply"
    grep -Eq "^from:[[:space:]]*$agent([[:space:]]|$)" "$reply"
  done
  echo "PASS: $agent replied on and archived all ${#tokens[@]} exact messages"
done

awk -F '\t' '
    $2 == "first-batch-archived" && $3 == "iot.codex" { archived = $1 }
    $2 == "post-batch-sent" && $3 == "iot.codex" { sent = $1 }
    END { exit !(archived > 0 && sent > archived) }
  ' "$root/scenario/events.tsv"
echo "PASS: Codex post-batch arrival was created only after its bounded burst was durably archived"
