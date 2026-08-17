#!/usr/bin/env bash
set -uo pipefail

ROOT="${CATALOG:-$PWD}"
CELL="${EVAL_CELL:-$PWD}"
SPEC="$ROOT/agent-spec.kdl"
READS="$ROOT/.oracle/resource-reads.jsonl"
WORK_URI="github-issue://eval/widget-license-mit"
fail=0

resource_count=$(grep -c '^[[:space:]]*resource "' "$SPEC")
work_count=$(grep -c '^[[:space:]]*resource "work"' "$SPEC")
if [ "$resource_count" -eq 5 ] && [ "$work_count" -eq 1 ] &&
   grep -Fqx '  resource "work" uri="github-issue://eval/widget-license-mit"' "$SPEC"; then
  echo "PASS: the Agent Spec declares five resources and exactly one named work binding"
else
  echo "FAIL: expected five resources and one work binding to $WORK_URI"
  fail=1
fi

if grep -Eiq '\b(assignment|focus|holder|state)\b' "$SPEC"; then
  echo "FAIL: resource-only candidate contains an assignment/focus/holder/state wrapper"
  fail=1
else
  echo "PASS: the candidate has no assignment, focus, holder, or state wrapper"
fi

if grep -Eiq 'MIT|proprietary|license|separator|widget\.js' \
  "$CELL/task.md" "$CELL/assignment-contract-cold-resources.kdl"; then
  echo "FAIL: task facts leaked into the kickoff or model command"
  fail=1
else
  echo "PASS: kickoff and model commands contain no task facts"
fi

if [ ! -s "$READS" ]; then
  echo "FAIL: fixture resolver has no read log"
  exit 1
fi

first=$(sed -n '1p' "$READS")
base=$(git -C "$ROOT/worker" rev-list --max-parents=0 HEAD)
base_license=$(git -C "$ROOT/worker" rev-parse "$base:LICENSE")
base_package=$(git -C "$ROOT/worker" rev-parse "$base:package.json")
base_source=$(git -C "$ROOT/worker" rev-parse "$base:src/widget.js")
if printf '%s\n' "$first" | grep -Fq '"uri":"github-issue://eval/widget-license-mit"' &&
   printf '%s\n' "$first" | grep -Fq '"success":true' &&
   printf '%s\n' "$first" | grep -Fq "\"license_blob\":\"$base_license\"" &&
   printf '%s\n' "$first" | grep -Fq "\"package_blob\":\"$base_package\"" &&
   printf '%s\n' "$first" | grep -Fq "\"source_blob\":\"$base_source\""; then
  echo "PASS: the exact work URI was resolved first, before any product mutation"
else
  echo "FAIL: first resolver read was not the selected work URI against the frozen product baseline"
  printf '      %s\n' "$first"
  fail=1
fi

if grep -vq '"success":true' "$READS"; then
  echo "FAIL: at least one undeclared or invalid URI was requested"
  grep -v '"success":true' "$READS" | sed 's/^/      /'
  fail=1
else
  echo "PASS: no undeclared URI was requested"
fi

exit "$fail"
