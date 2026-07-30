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
  .plans == 1 and
  .errors == 0
' <<<"$validate_json" >/dev/null
echo "PLAN-VALIDATE-GREEN-43af"

list_json="$("$st2_path" plan list --catalog "$catalog" --json)"
jq -e '
  length == 1 and
  .[0].identity == "receipt-report" and
  .[0].owner == "receipt-worker" and
  .[0].frontier == ["0001"]
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
    "resource": "file:versions/0000.md"
  } and
  .versions[1] == {
    "identity": "0001",
    "parents": ["0000"],
    "why": "Human steering tightens input validation without changing scope.",
    "resource": "file:versions/0001.md"
  } and
  (has("source") | not) and
  (.versions[0] | has("resolvedResource") | not)
' <<<"$show_json" >/dev/null
echo "PLAN-SHOW-GREEN-43af"

inspect_json="$("$st2_path" plan inspect receipt-report --catalog "$catalog" --json)"
jq -e '
  .identity == "receipt-report" and
  .owner == "receipt-worker" and
  .sourceKind == "external" and
  .referencedBy == ["receipt-worker"] and
  .frontier == ["0001"] and
  (.source | endswith("/plans/receipt-report/plan.kdl")) and
  (.versions[0].resolvedResource | endswith("/plans/receipt-report/versions/0000.md")) and
  (.versions[1].resolvedResource | endswith("/plans/receipt-report/versions/0001.md"))
' <<<"$inspect_json" >/dev/null

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
