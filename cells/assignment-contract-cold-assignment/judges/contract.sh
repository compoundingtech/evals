#!/usr/bin/env bash
set -uo pipefail

ROOT="${CATALOG:-$PWD}"
CELL="${EVAL_CELL:-$PWD}"
SPEC="$ROOT/agent-spec.kdl"
READS="$ROOT/.oracle/resource-reads.jsonl"
WORK_URI="github-issue://eval/widget-license-mit"

fail=0
[ -f "$SPEC" ] || { echo "FAIL: missing experimental Agent Spec"; exit 1; }

resources=$(grep -cE '^[[:space:]]*resource "' "$SPEC")
assignments=$(grep -cE '^[[:space:]]*assignment "' "$SPEC")
[ "$resources" -eq 5 ] || { echo "FAIL: expected 5 direct Resources, found $resources"; fail=1; }
[ "$assignments" -eq 1 ] || { echo "FAIL: expected exactly one Assignment, found $assignments"; fail=1; }
grep -qF 'assignment "active" _tag="coding-task" id="github-issue://eval/widget-license-mit"' "$SPEC" \
  || { echo "FAIL: Assignment is not minimal active tagged work with shared stable ID"; fail=1; }
grep -Fqx '  resource "intent" _tag="github-issue" uri="github-issue://eval/widget-license-mit"' "$SPEC" \
  || { echo "FAIL: intent Resource URI does not equal the Assignment ID"; fail=1; }
grep -qF 'uses "intent" "source" "worklog" "delivery"' "$SPEC" \
  || { echo "FAIL: Assignment does not use the four selected bindings"; fail=1; }
if grep -Eq 'lease|progress|workflow|holder|acceptance|phase|status=' "$SPEC"; then
  echo "FAIL: Assignment contains an extra lifecycle/workflow field"; fail=1
fi

if grep -Eiq 'MIT|proprietary|license|separator|widget\.js' \
  "$CELL/task.md" "$CELL/assignment-contract-cold-assignment.kdl"; then
  echo "FAIL: kickoff leaks task or Resource facts"; fail=1
else
  echo "PASS: kickoff and model commands contain no task facts"
fi

if [ ! -s "$READS" ]; then
  echo "FAIL: fixture resolver has no read log"
  exit 1
else
  first=$(sed -n '1p' "$READS")
  base=$(git -C "$ROOT/worker" rev-list --max-parents=0 HEAD)
  base_license=$(git -C "$ROOT/worker" rev-parse "$base:LICENSE")
  base_package=$(git -C "$ROOT/worker" rev-parse "$base:package.json")
  base_source=$(git -C "$ROOT/worker" rev-parse "$base:src/widget.js")
  if printf '%s\n' "$first" | grep -Fq "\"uri\":\"$WORK_URI\"" &&
     printf '%s\n' "$first" | grep -Fq '"success":true' &&
     printf '%s\n' "$first" | grep -Fq "\"license_blob\":\"$base_license\"" &&
     printf '%s\n' "$first" | grep -Fq "\"package_blob\":\"$base_package\"" &&
     printf '%s\n' "$first" | grep -Fq "\"source_blob\":\"$base_source\""; then
    echo "PASS: exact assigned work URI was resolved first, before product mutation"
  else
    echo "FAIL: first resolver read was not assigned work against the frozen baseline"
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
fi

[ "$fail" -eq 0 ] && echo "PASS: minimal Assignment selected the exact current work"
exit "$fail"
