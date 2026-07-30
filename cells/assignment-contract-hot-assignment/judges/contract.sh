#!/usr/bin/env bash
set -uo pipefail

ROOT="${CATALOG:-$PWD}"
CELL="${EVAL_CELL:-$PWD}"
SPEC="$ROOT/agent-spec.kdl"
READS="$ROOT/.oracle/resource-reads.tsv"
A_URI="github-issue://eval/names-normalize"
B_URI="github-issue://eval/names-format-label"
fail=0

resources=$(grep -cE '^[[:space:]]*resource "' "$SPEC")
assignments=$(grep -cE '^[[:space:]]*assignment "' "$SPEC")
if [ "$resources" -ne 4 ]; then
  echo "FAIL: expected four direct Resources to remain available, found $resources"
  fail=1
else
  echo "PASS: all four direct Resources remain available at idle"
fi
if [ "$assignments" -ne 1 ] ||
   ! grep -Fqx '  assignment "idle"' "$SPEC" ||
   grep -qE '^[[:space:]]*assignment "active"|^[[:space:]]*uses ' "$SPEC"; then
  echo "FAIL: final durable context is not exactly one minimal idle Assignment"
  fail=1
else
  echo "PASS: one minimal idle Assignment is the explicit negative work state"
fi
if grep -Eq 'lease|progress|workflow|holder|acceptance|phase|status=|^[[:space:]]*focus ' "$SPEC"; then
  echo "FAIL: Assignment treatment contains an extra lifecycle field or Focus"
  fail=1
else
  echo "PASS: Assignment adds no lifecycle/workflow fields or Focus"
fi

INITIAL="$CELL/fixture/agent-spec.kdl"
if grep -Fqx \
     '  assignment "active" _tag="coding-task" id="github-issue://eval/names-normalize" {' "$INITIAL" &&
   grep -Fqx '    uses "work" "source" "delivery"' "$INITIAL"; then
  echo "PASS: initial Assignment is minimal active work with ID equal to its selected Resource URI"
else
  echo "FAIL: initial active Assignment shape is not the intended treatment"
  fail=1
fi

if grep -Eiq 'normalize|format-label|format label|formatlabel|reverse|joinNames' \
  "$CELL/task.md" "$CELL/assignment-contract-hot-assignment.kdl"; then
  echo "FAIL: product task facts leaked into kickoff or model commands"
  fail=1
else
  echo "PASS: kickoff and model commands contain no product task facts"
fi

notification=$(sed -n '/^notify_change()/,/^}/p' "$ROOT/controller.sh")
if grep -Eiq 'normalize|format-label|format label|formatlabel|reverse|joinNames' <<<"$notification"; then
  echo "FAIL: controller notification body contains product task facts"
  fail=1
else
  echo "PASS: controller notification body is a task-free durable-context signal"
fi

if grep -Fqx '  resource "work" _tag="github-issue" uri="github-issue://eval/names-format-label"' "$SPEC"; then
  echo "PASS: the last work Resource remains present but is not assigned"
else
  echo "FAIL: final context did not retain the phase B work Resource"
  fail=1
fi

if [ ! -s "$READS" ]; then
  echo "FAIL: no resource resolver log"
  exit 1
fi

invalid=$(awk -F '\t' '$3 != "true" { print }' "$READS")
if [ -z "$invalid" ]; then
  echo "PASS: every resolver read addressed a resource declared at read time"
else
  echo "FAIL: undeclared resource reads occurred"
  printf '%s\n' "$invalid" | sed 's/^/      /'
  fail=1
fi

actual_work_reads=$(awk -F '\t' -v a="$A_URI" -v b="$B_URI" '$2 == a || $2 == b { print $2 }' "$READS")
if [ "$actual_work_reads" = "$A_URI
$B_URI" ]; then
  echo "PASS: exact work resources were resolved once each in A-then-B order"
else
  echo "FAIL: expected exact A-then-B work reads, got:"
  printf '%s\n' "$actual_work_reads" | sed 's/^/      /'
  fail=1
fi

if grep -Fq 'github-pr://eval/names-reverse' "$READS"; then
  echo "FAIL: worker acted on or inspected the distractor as work"
  fail=1
else
  echo "PASS: distractor pull request was not resolved"
fi

exit "$fail"
