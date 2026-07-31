#!/usr/bin/env bash
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
manifest="$here/../fixture/cases.tsv"
oracle="$here/contract.sh"
tmp="$(mktemp -d "${TMPDIR:-/tmp}/agent-spec-field-change-self-test.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT

good="$tmp/good.out"
awk -F '\t' 'BEGIN { OFS="\t" } NR > 1 { print "RESULT", $1, $2, $3, $4, $3, "planted-observation" }' \
  "$manifest" >"$good"
printf 'SUMMARY\tconformance-pass=4\texpected-red=14\tunexpected=0\n' >>"$good"
printf 'ZERO-RESIDUE\texec=0\tpty=0\tprocess=0\tcatalogs=18\n' >>"$good"

for mode in coverage gaps classification honesty cleanup; do
  bash "$oracle" "$mode" "$good" "$manifest" >/dev/null
done
echo "PASS: canonical static receipt satisfies all five oracle modes"

missing="$tmp/missing.tsv"
awk -F '\t' '$2 != "F16"' "$manifest" >"$missing"
if bash "$oracle" coverage "$good" "$missing" >/dev/null 2>&1; then
  echo "FAIL: missing F16 case passed coverage" >&2
  exit 1
fi
echo "PASS: missing-field mutation fails coverage"

unknown_gap="$tmp/unknown-gap.tsv"
sed 's/F01\tRED\tG01/F01\tRED\tG09/' "$manifest" >"$unknown_gap"
if bash "$oracle" gaps "$good" "$unknown_gap" >/dev/null 2>&1; then
  echo "FAIL: unknown G09 gap passed mapping" >&2
  exit 1
fi
echo "PASS: unknown-gap mutation fails mapping"

red_as_pass="$tmp/red-as-pass.out"
sed $'s/RESULT\tidentity-remove-add\tF02\tRED\tG03\tRED/RESULT\tidentity-remove-add\tF02\tRED\tG03\tPASS/' \
  "$good" >"$red_as_pass"
if bash "$oracle" honesty "$red_as_pass" "$manifest" >/dev/null 2>&1; then
  echo "FAIL: expected red counted as pass" >&2
  exit 1
fi
echo "PASS: expected-red-as-pass mutation fails honesty"

drift="$tmp/drift.out"
sed $'s/RESULT\thost-projection\tF03/RESULT\thost-projection\tF99/' "$good" >"$drift"
if bash "$oracle" classification "$drift" "$manifest" >/dev/null 2>&1; then
  echo "FAIL: result field drift passed classification" >&2
  exit 1
fi
echo "PASS: result-drift mutation fails classification"

no_cleanup="$tmp/no-cleanup.out"
grep -v '^ZERO-RESIDUE' "$good" >"$no_cleanup"
if bash "$oracle" cleanup "$no_cleanup" "$manifest" >/dev/null 2>&1; then
  echo "FAIL: missing cleanup receipt passed" >&2
  exit 1
fi
echo "PASS: missing-residue-receipt mutation fails cleanup"

echo "STATIC-ORACLE-SELF-TEST-GREEN-f102"
