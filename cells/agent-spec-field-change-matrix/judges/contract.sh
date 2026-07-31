#!/usr/bin/env bash
set -euo pipefail

mode="${1:?mode required}"
output="${2:?matrix output required}"
manifest="${3:?case manifest required}"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

test -f "$manifest" || fail "missing manifest $manifest"
test -f "$output" || fail "missing matrix output $output"

coverage() {
  awk -F '\t' '
    NR == 1 {
      if ($0 != "case_id\tfields\texpected\tgaps\tcontract") exit 10
      next
    }
    NF != 5 || $1 == "" || $5 == "" { exit 11 }
    { seen_case[$1]++; fields = fields (fields == "" ? "" : ",") $2 }
    END {
      if (NR != 19) exit 12
      for (case_id in seen_case) if (seen_case[case_id] != 1) exit 13
      if (fields != "F01,F02,F03,F04,F05,F06,F07,F08,F09,F10,F11,F12,F13,F14,F15,F16,R05,MOVED") exit 14
    }
  ' "$manifest" || fail "manifest is not the exact F01-F16 plus R05/MOVED closed set"
  echo "PASS: 18 unique cases cover F01-F16 plus dry-run ordering and moved intent"
}

gaps() {
  awk -F '\t' '
    NR == 1 { next }
    $3 == "PASS" {
      if ($4 != "-") exit 20
      pass++
      next
    }
    $3 != "RED" { exit 21 }
    {
      red++
      count = split($4, parts, ",")
      if (count < 1) exit 22
      for (i = 1; i <= count; i++) {
        if (parts[i] !~ /^G0[1-8]$/) exit 23
        seen[parts[i]] = 1
      }
    }
    END {
      if (pass != 4 || red != 14) exit 24
      for (i = 1; i <= 8; i++) {
        gap = sprintf("G%02d", i)
        if (!(gap in seen)) exit 25
      }
    }
  ' "$manifest" || fail "expected-red map is not limited to and complete across G01-G08"
  echo "PASS: 14 expected reds map only to named gaps G01-G08; 4 cases are existing passes"
}

classification() {
  awk -F '\t' '
    NR == FNR {
      if (FNR == 1) next
      fields[$1] = $2
      expected[$1] = $3
      gaps[$1] = $4
      cases[$1] = 1
      manifest_count++
      next
    }
    $1 != "RESULT" { next }
    {
      case_id = $2
      if (!(case_id in cases) || seen[case_id]++) exit 30
      if ($3 != fields[case_id] || $4 != expected[case_id] || $5 != gaps[case_id]) exit 31
      if ($6 != expected[case_id]) exit 32
      result_count++
    }
    END {
      if (manifest_count != 18 || result_count != manifest_count) exit 33
      for (case_id in cases) if (!(case_id in seen)) exit 34
    }
  ' "$manifest" "$output" || fail "product results drift from the exact closed-set pass/red map"
  echo "PASS: all 18 product observations match the frozen classification"
}

honesty() {
  awk -F '\t' '
    NR == FNR {
      if (FNR > 1) expected[$1] = $3
      next
    }
    $1 == "RESULT" {
      if (expected[$2] == "RED" && $6 != "RED") exit 40
      if ($6 == "PASS") pass++
      if ($6 == "RED") red++
      next
    }
    $1 == "SUMMARY" {
      summary++
      if ($2 != "conformance-pass=4" || $3 != "expected-red=14" || $4 != "unexpected=0") exit 41
    }
    END {
      if (summary != 1 || pass != 4 || red != 14) exit 42
    }
  ' "$manifest" "$output" || fail "an expected red was counted as conformance or the summary drifted"
  echo "PASS: no expected product red is counted as a conformance pass"
}

cleanup() {
  count="$(grep -Fxc $'ZERO-RESIDUE\texec=0\tpty=0\tprocess=0\tcatalogs=18' "$output" || true)"
  test "$count" -eq 1 || fail "missing exact zero-residue receipt"
  echo "PASS: exact cleanup receipt proves zero exec, PTY, and process residue"
}

case "$mode" in
  coverage) coverage ;;
  gaps) gaps ;;
  classification) classification ;;
  honesty) honesty ;;
  cleanup) cleanup ;;
  *) fail "unknown contract mode $mode" ;;
esac
