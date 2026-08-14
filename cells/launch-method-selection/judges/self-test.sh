#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
judge="$root/judges/contract.sh"
cases="$root/fixture/cases.tsv"
tmp="$(mktemp -d)"
trap 'rm -rf -- "$tmp"' EXIT

write_baseline() {
  output="$1"
  pass_count=0
  red_count=0
  {
    while IFS=$'\t' read -r case_id expected gaps _; do
      [ "$case_id" = "case_id" ] && continue
      printf 'CASE\t%s\t%s\t%s\n' "$case_id" "$expected" "$gaps"
      if [ "$expected" = PASS ]; then
        ((pass_count += 1))
      else
        ((red_count += 1))
      fi
    done < "$cases"
    printf 'SUMMARY pass=%d red=%d\n' "$pass_count" "$red_count"
    if [ "$red_count" -gt 0 ]; then
      printf '%s\n' 'PRODUCT-RED launch-method-selection'
    else
      printf '%s\n' 'PRODUCT-GREEN launch-method-selection'
    fi
    printf '%s\n' 'ZERO-RESIDUE pty=0 process=0 catalogs=5'
  } > "$output"
}

baseline="$tmp/baseline.out"
write_baseline "$baseline"
for mode in coverage gaps classification honesty cleanup; do
  "$judge" "$mode" "$baseline" "$cases"
done

mutations=0

missing="$tmp/missing.out"
sed '/explicit-resume-exact/d' "$baseline" > "$missing"
! "$judge" coverage "$missing" "$cases"
((mutations += 1))

duplicate="$tmp/duplicate.out"
awk '1; /explicit-resume-exact/ { print }' "$baseline" > "$duplicate"
! "$judge" coverage "$duplicate" "$cases"
((mutations += 1))

misclassified="$tmp/misclassified.out"
awk -F '\t' 'BEGIN { OFS = "\t" } $1 == "CASE" && $2 == "explicit-start-new-session" { $3 = ($3 == "PASS" ? "RED" : "PASS"); $4 = ($3 == "PASS" ? "-" : "P01") } { print }' \
  "$baseline" > "$misclassified"
! "$judge" classification "$misclassified" "$cases"
((mutations += 1))

unknown_gap="$tmp/unknown-gap.out"
awk -F '\t' 'BEGIN { OFS = "\t" } $1 == "CASE" && $2 == "explicit-resume-exact" { $3 = "RED"; $4 = "P99" } { print }' \
  "$baseline" > "$unknown_gap"
! "$judge" gaps "$unknown_gap" "$cases"
((mutations += 1))

missing_cleanup="$tmp/missing-cleanup.out"
sed '/^ZERO-RESIDUE /d' "$baseline" > "$missing_cleanup"
! "$judge" cleanup "$missing_cleanup" "$cases"
((mutations += 1))

false_honesty="$tmp/false-honesty.out"
if grep -Fq 'PRODUCT-RED launch-method-selection' "$baseline"; then
  sed 's/^PRODUCT-RED /PRODUCT-GREEN /' "$baseline" > "$false_honesty"
else
  sed 's/^PRODUCT-GREEN /PRODUCT-RED /' "$baseline" > "$false_honesty"
fi
! "$judge" honesty "$false_honesty" "$cases"
((mutations += 1))

printf 'PASS: %d launch-method contract mutations rejected\n' "$mutations"
