#!/usr/bin/env bash
set -euo pipefail

results="$CATALOG/results"
network="$CATALOG/network"
spec_a="$CATALOG/source/a/agents/h/seat/agent.kdl"
spec_b="$CATALOG/source/b/agents/h/seat/agent.kdl"
mkdir -p "$results" "$network/agents/h/seat/resources"

capture() {
  local name=$1
  shift
  set +e
  "$@" >"$results/$name.json" 2>"$results/$name.err"
  local code=$?
  set -e
  printf '%s\n' "$code" >"$results/$name.code"
}

stage() {
  local name=$1 spec=$2 manager=$3 operation=$4
  shift 4
  capture "$name" st2 --catalog "$network" catalog stage "$spec" \
    --manager "$manager" \
    --state-relative agents/h/seat \
    --operation-id "$operation" \
    "$@"
}

capture head-before st2 --catalog "$network" catalog head
stage publish-a "$spec_a" nix stage-a
cp "$results/publish-a.code" "$results/setup.code"

ref_a=$(jq -er .refCommit "$results/publish-a.json")
binding_a=$(jq -er .resourceBindingCommit "$results/publish-a.json")

# Simulate an acknowledged result being lost, then replay the same operation.
stage replay-a "$spec_a" nix stage-a

# A foreign manager must not advance a Nix-owned ref.
stage foreign "$spec_b" human foreign \
  --expected-ref "$ref_a" --binding-parent "$binding_a"

# Advance A -> B -> A with immutable parent commits.
stage publish-b "$spec_b" nix stage-b \
  --expected-ref "$ref_a" --binding-parent "$binding_a"
ref_b=$(jq -er .refCommit "$results/publish-b.json")
binding_b=$(jq -er .resourceBindingCommit "$results/publish-b.json")

stage publish-a2 "$spec_a" nix stage-a2 \
  --expected-ref "$ref_b" --binding-parent "$binding_b"
ref_a2=$(jq -er .refCommit "$results/publish-a2.json")
printf '%s\n' "$ref_a2" >"$results/expected-final-ref"

# The ref points at A again, but the old A parent commit is stale.
stage stale "$spec_b" nix stale-a-parent \
  --expected-ref "$ref_a" --binding-parent "$binding_a"
stage replay-a2 "$spec_a" nix stage-a2 \
  --expected-ref "$ref_b" --binding-parent "$binding_b"

capture head-after st2 --catalog "$network" catalog head
