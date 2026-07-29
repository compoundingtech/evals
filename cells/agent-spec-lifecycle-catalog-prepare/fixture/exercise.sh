#!/usr/bin/env bash
set -euo pipefail

results="$CATALOG/results"
network="$CATALOG/network"
spec="$CATALOG/source/agents/h/seat/agent.kdl"
mkdir -p "$results" "$CATALOG/expected"
cp "$spec" "$CATALOG/expected/agent.kdl"

capture() {
  local name=$1
  shift
  set +e
  "$@" >"$results/$name.json" 2>"$results/$name.err"
  local code=$?
  set -e
  printf '%s\n' "$code" >"$results/$name.code"
}

capture head-before st2 --catalog "$network" catalog head
capture prepare st2 --catalog "$network" catalog prepare "$spec"
capture prepare-again st2 --catalog "$network" catalog prepare "$spec"

# Source bytes are mutable after the import. The catalog object is not.
printf '\n// later source mutation\n' >>"$spec"
capture head-after st2 --catalog "$network" catalog head
