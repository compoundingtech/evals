#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

cases_root="cells/agent-new-interview/fixture/cases"
cases=(hard-constraint implementation investigation small-fix)
model_context=(
  cells/agent-new-interview/fixture/interviewer/CLAUDE.md
  cells/agent-new-interview/fixture/interviewer/PERSONA.md
  cells/agent-new-interview/fixture/interviewer/PROTOCOL.md
)

for case_name in "${cases[@]}"; do
  case_root="$cases_root/$case_name"
  task="$case_root/task.md"
  constraints="$case_root/hard-constraints.json"
  expected="$case_root/expected.json"
  test -f "$task" && test -f "$constraints" && test -f "$expected"
  test "$(awk 'NF { rows += 1 } END { print rows + 0 }' "$task")" -eq 1
  jq -e '
    type == "object" and
    (.identity | test("^[a-z0-9-]+\\.[a-z0-9-]+\\.[a-z0-9-]+\\.[a-z0-9-]+$")) and
    (.goalTerms | type == "array" and length > 0) and
    (.references | type == "array") and
    (.trajectory | keys | sort) == ([
      "boot", "effort", "harness", "mode", "model", "persona"
    ] | sort)
  ' "$expected" >/dev/null
  jq -e '
    type == "object" and
    (keys | all(. == "harness" or . == "model" or . == "effort" or
      . == "persona" or . == "supervisor"))
  ' "$constraints" >/dev/null
  identity="$(jq -r .identity "$expected")"
  if rg -Fq "$identity" "${model_context[@]}"; then
    echo "FAIL: held-out identity for $case_name leaked into model-facing context" >&2
    exit 1
  fi
done

test "$(jq '.references | length' "$cases_root/small-fix/expected.json")" -eq 0
test "$(jq 'length' "$cases_root/hard-constraint/hard-constraints.json")" -ge 5

for cell in \
  agent-new-interview \
  agent-new-interview-hard-constraint \
  agent-new-interview-investigation \
  agent-new-interview-small-fix; do
  test -f "cells/$cell/$cell.kdl"
done

echo "PASS: four one-sentence paid cases keep expected decisions held out and hard constraints explicit"
