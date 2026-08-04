#!/usr/bin/env bash
set -euo pipefail

root="${CATALOG:?CATALOG must be set}"
runner="$root/runner.tsv"
catalog="$root/arm-a/catalog"
invalid="$root/invalid/current"
st2_path="$(command -v st2)"

value() {
  awk -F '\t' -v key="$1" '$1 == key { print $2 }' "$runner"
}

source_short="$(value source_short)"
expected_sha="$(value binary_sha256)"
version_regex="^st2 0\\.1\\.0 — running from local source \\(${source_short}, .+ ago\\)$"
actual_version="$("$st2_path" --version)"
actual_sha="$(sha256sum "$st2_path" | awk '{print $1}')"
[[ "$actual_version" =~ $version_regex ]]
test "$actual_sha" = "$expected_sha"
echo "PLAN-RUNNER-PIN-GREEN-43af"

before="$(mktemp)"
after="$(mktemp)"
invalid_json="$(mktemp)"
cleanup() {
  rm -f -- "$before" "$after" "$invalid_json"
}
trap cleanup EXIT

find "$catalog" -type f -print0 |
  LC_ALL=C sort -z |
  xargs -0 sha256sum >"$before"

validate_json="$("$st2_path" plan validate --catalog "$catalog" --json)"
jq -e '
  .result == "valid" and
  .plans == 2 and
  .errors == 0
' <<<"$validate_json" >/dev/null
echo "PLAN-VALIDATE-GREEN-43af"

list_json="$("$st2_path" plan list --catalog "$catalog" --json)"
jq -e '
  length == 2 and
  .[0] == {
    "identity": "inline-intent",
    "owner": "receipt-worker",
    "frontier": ["0000"]
  } and
  .[1] == {
    "identity": "receipt-report",
    "owner": "receipt-worker",
    "frontier": ["0001"]
  }
' <<<"$list_json" >/dev/null
echo "PLAN-LIST-GREEN-43af"

show_json="$("$st2_path" plan show receipt-report --catalog "$catalog" --json)"
jq -e '
  .identity == "receipt-report" and
  .owner == "receipt-worker" and
  .frontier == ["0001"] and
  (.versions | length) == 2 and
  .versions[0] == {
    "identity": "0000",
    "parents": [],
    "why": null,
    "content": "file:versions/0000.md"
  } and
  .versions[1] == {
    "identity": "0001",
    "parents": ["0000"],
    "why": "Human steering tightens input validation without changing scope.",
    "content": "file:versions/0001.md"
  } and
  (has("source") | not) and
  (.versions[0] | has("resolvedContent") | not)
' <<<"$show_json" >/dev/null
echo "PLAN-SHOW-GREEN-43af"

inspect_json="$("$st2_path" plan inspect receipt-report --catalog "$catalog" --json)"
jq -e '
  .identity == "receipt-report" and
  .owner == "receipt-worker" and
  .sourceKind == "external" and
  .referencedBy == ["receipt-worker"] and
  .frontier == ["0001"] and
  (.source | endswith("/agents/eval/receipt-worker/plans/receipt-report/plan.kdl")) and
  (.versions[0].resolvedContent | endswith("/agents/eval/receipt-worker/plans/receipt-report/versions/0000.md")) and
  (.versions[1].resolvedContent | endswith("/agents/eval/receipt-worker/plans/receipt-report/versions/0001.md"))
' <<<"$inspect_json" >/dev/null

inline_show_json="$("$st2_path" plan show inline-intent --catalog "$catalog" --json)"
jq -e '
  .identity == "inline-intent" and
  .owner == "receipt-worker" and
  .frontier == ["0000"] and
  .versions == [{
    "identity": "0000",
    "parents": [],
    "why": null,
    "intent": "Keep the complete inline intent in plan.kdl."
  }] and
  (has("source") | not) and
  (.versions[0] | has("content") | not) and
  (.versions[0] | has("resolvedContent") | not)
' <<<"$inline_show_json" >/dev/null

inline_inspect_json="$("$st2_path" plan inspect inline-intent --catalog "$catalog" --json)"
jq -e '
  .identity == "inline-intent" and
  .sourceKind == "external" and
  .referencedBy == ["receipt-worker"] and
  (.source | endswith("/agents/eval/receipt-worker/plans/inline-intent/plan.kdl")) and
  .versions[0].intent == "Keep the complete inline intent in plan.kdl." and
  (.versions[0] | has("content") | not) and
  (.versions[0] | has("resolvedContent") | not)
' <<<"$inline_inspect_json" >/dev/null
echo "PLAN-TARGET-FORMS-GREEN-43af"

find "$catalog" -type f -print0 |
  LC_ALL=C sort -z |
  xargs -0 sha256sum >"$after"
cmp -s "$before" "$after"
test ! -e "$catalog/.st2"
echo "PLAN-INSPECT-READONLY-GREEN-43af"

if "$st2_path" plan validate --catalog "$invalid" --json >"$invalid_json" 2>/dev/null; then
  echo "unsupported current pointer unexpectedly validated" >&2
  exit 1
fi
jq -e '
  .result == "invalid" and
  .code == "unsupported-plan-field" and
  (.error | contains("unsupported-current")) and
  (.error | contains("current"))
' "$invalid_json" >/dev/null
echo "PLAN-BOUNDARY-GREEN-43af"
