#!/usr/bin/env bash
set -uo pipefail

ROOT="${CATALOG:-$PWD}"
CELL="${EVAL_CELL:-$PWD}"
SPEC="$ROOT/agent-spec.kdl"
READS="$ROOT/.oracle/resource-reads.tsv"
A_URI="github-issue://eval/names-normalize"
B_URI="github-issue://eval/names-format-label"
fail=0

resource_count=$(grep -c '^[[:space:]]*resource "' "$SPEC")
if [ "$resource_count" -eq 3 ] &&
   grep -Fqx '  resource "source" uri="worktree://eval/names"' "$SPEC" &&
   grep -Fqx '  resource "delivery" uri="ding://eval/ahr.worker"' "$SPEC" &&
   grep -Fqx '  resource "review-context" uri="github-pr://eval/names-reverse"' "$SPEC"; then
  echo "PASS: final Agent Spec retains exactly the three non-work Resources"
else
  echo "FAIL: final resource-only context is not the exact idle three-Resource shape"
  fail=1
fi

INITIAL="$CELL/fixture/agent-spec.kdl"
if [ "$(grep -c '^[[:space:]]*resource "' "$INITIAL")" -eq 4 ] &&
   grep -Fqx '  resource "work" uri="github-issue://eval/names-normalize"' "$INITIAL"; then
  echo "PASS: initial Agent Spec has exactly four Resources with phase A bound as work"
else
  echo "FAIL: initial resource-only context is not the intended four-Resource shape"
  fail=1
fi

if grep -Eiq '\b(assignment|focus|holder|state)\b' "$SPEC"; then
  echo "FAIL: resource-only candidate contains an assignment/focus/holder/state wrapper"
  fail=1
else
  echo "PASS: candidate has no assignment, focus, holder, or state wrapper"
fi

if grep -Eiq 'normalize|format-label|format label|formatlabel|reverse|joinNames' \
  "$CELL/task.md" "$CELL/assignment-contract-hot-resources.kdl"; then
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

if grep -q '^[[:space:]]*resource "work"' "$SPEC"; then
  echo "FAIL: final durable context should have no work binding"
  fail=1
else
  echo "PASS: controller removed the work binding to represent idle"
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
