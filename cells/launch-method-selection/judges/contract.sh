#!/usr/bin/env bash
set -euo pipefail

mode="${1:?mode is required}"
observed="${2:?observed output is required}"
cases="${3:?case manifest is required}"

case_rows() {
  awk -F '\t' '$1 == "CASE" { print $2 "\t" $3 "\t" $4 }' "$observed"
}

expected_rows() {
  awk -F '\t' 'NR > 1 { print $1 "\t" $2 "\t" $3 }' "$cases"
}

case "$mode" in
  coverage)
    expected_ids="$(awk -F '\t' 'NR > 1 { print $1 }' "$cases")"
    observed_ids="$(case_rows | cut -f1)"
    test "$observed_ids" = "$expected_ids"
    test "$(printf '%s\n' "$observed_ids" | sort -u | wc -l)" -eq "$(printf '%s\n' "$observed_ids" | wc -l)"
    ;;
  gaps)
    while IFS=$'\t' read -r _ outcome gaps; do
      if [ "$outcome" = "PASS" ]; then
        test "$gaps" = "-"
      else
        printf '%s\n' "$gaps" | grep -Eq '^P0[1-6](,P0[1-6])*$'
      fi
    done < <(case_rows)
    ;;
  classification)
    test "$(case_rows)" = "$(expected_rows)"
    ;;
  honesty)
    red_count="$(case_rows | awk -F '\t' '$2 == "RED" { count += 1 } END { print count + 0 }')"
    pass_count="$(case_rows | awk -F '\t' '$2 == "PASS" { count += 1 } END { print count + 0 }')"
    grep -Fqx "SUMMARY pass=$pass_count red=$red_count" "$observed"
    test "$(grep -Ec '^PRODUCT-(RED|GREEN) launch-method-selection$' "$observed")" -eq 1
    if [ "$red_count" -gt 0 ]; then
      grep -Fqx "PRODUCT-RED launch-method-selection" "$observed"
    else
      grep -Fqx "PRODUCT-GREEN launch-method-selection" "$observed"
    fi
    ;;
  cleanup)
    grep -Fqx "ZERO-RESIDUE pty=0 process=0 catalogs=5" "$observed"
    ;;
  *)
    printf 'unknown judge mode: %s\n' "$mode" >&2
    exit 2
    ;;
esac
