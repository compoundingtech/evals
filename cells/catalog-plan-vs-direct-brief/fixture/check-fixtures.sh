#!/usr/bin/env bash
set -euo pipefail

root="${CATALOG:?CATALOG must be set}"
experiment="$root/experiment.tsv"
arms="$root/arms.tsv"
scenario="$root/scenario.tsv"
measurements="$root/measurement-schema.tsv"
receipts="$root/receipt-schema.tsv"
blockers="$root/blockers.tsv"
lineage="$root/arm-a/catalog/plans/receipt-report/lineage.tsv"
thread="$root/arm-b/inbox/thread.tsv"
plan_0000="$root/arm-a/catalog/plans/receipt-report/versions/0000.md"
plan_0001="$root/arm-a/catalog/plans/receipt-report/versions/0001.md"
brief_0000="$root/arm-b/inbox/brief-0000.md"
brief_0001="$root/arm-b/inbox/brief-0001.md"

expect_header() {
  file="$1"
  expected="$2"
  test "$(head -n 1 "$file")" = "$expected"
}

tree_hash() {
  (
    cd "$1"
    find . -type f -print0 |
      LC_ALL=C sort -z |
      xargs -0 sha256sum |
      sha256sum |
      awk '{print $1}'
  )
}

expect_header "$experiment" $'field\tvalue'
expect_header "$arms" $'arm\tinput_kind\tinitial_source\tlocal_resume_source\tsteering_source\treceipt_surface\tallowed_tools\twall_budget_seconds\tmodel_token_budget\tjudge_profile\tdone_condition'
expect_header "$scenario" $'ordinal\tevent\tarm_a_input\tarm_b_input\tinvariant'
expect_header "$measurements" $'metric\ttype\tunit\trole\tpreferred_direction\tmodel_free_value\tlive_source'
expect_header "$receipts" $'field\ttype\trequired\tdescription'
expect_header "$blockers" $'blocker_id\towner\tdependency\trequired_evidence\tstatus'
expect_header "$lineage" $'version\tparent\treason\tbody_sha256'
expect_header "$thread" $'revision\tparent\treason\tbody_sha256'

test "$(awk -F '\t' 'NR > 1 { count++ } END { print count + 0 }' "$arms")" -eq 2
test "$(awk -F '\t' 'NR > 1 { count++ } END { print count + 0 }' "$scenario")" -eq 6
test "$(awk -F '\t' 'NR > 1 { count++ } END { print count + 0 }' "$measurements")" -eq 10
test "$(awk -F '\t' 'NR > 1 { count++ } END { print count + 0 }' "$receipts")" -eq 17
test "$(awk -F '\t' 'NR > 1 { count++ } END { print count + 0 }' "$blockers")" -eq 2

grep -Fqx $'allowed_tools\tnode,bash,git' "$experiment"
grep -Fqx $'network_policy\tdisabled' "$experiment"
grep -Fqx $'wall_budget_seconds\t1200' "$experiment"
grep -Fqx $'model_token_budget\t40000' "$experiment"
grep -Fqx $'initial_revision\t0000' "$experiment"
grep -Fqx $'steering_revision\t0001' "$experiment"

cmp -s "$plan_0000" "$brief_0000"
cmp -s "$plan_0001" "$brief_0001"
test "$(sha256sum "$plan_0000" | awk '{print $1}')" != \
  "$(sha256sum "$plan_0001" | awk '{print $1}')"

awk -F '\t' '
  NR == 2 {
    tools = $7
    wall = $8
    tokens = $9
    judge = $10
    done = $11
    next
  }
  NR == 3 {
    if ($7 != tools || $8 != wall || $9 != tokens || $10 != judge || $11 != done) {
      exit 1
    }
  }
' "$arms"
grep -Fqx $'A\tversioned-catalog-plan\tarm-a/catalog/plans/receipt-report/versions/0000.md\tlocal catalog plan version plus evaluator receipt\tarm-a/catalog/plans/receipt-report/versions/0001.md\tarm-a/catalog/plans/receipt-report/receipts\tnode,bash,git\t1200\t40000\tarm-neutral-public-plus-held-out\tpublic and held-out tests pass; only src/report.mjs differs from the seed; no dependency or network change' "$arms"
grep -Fqx $'B\tdurable-direct-brief\tarm-b/inbox/brief-0000.md\tlocal durable brief thread plus evaluator receipt\tarm-b/inbox/brief-0001.md\tarm-b/receipts\tnode,bash,git\t1200\t40000\tarm-neutral-public-plus-held-out\tpublic and held-out tests pass; only src/report.mjs differs from the seed; no dependency or network change' "$arms"

expected_0000="$(sha256sum "$plan_0000" | awk '{print $1}')"
expected_0001="$(sha256sum "$plan_0001" | awk '{print $1}')"
grep -Fqx "0000	-	initial frozen repository task	$expected_0000" "$lineage"
grep -Fqx "0001	0000	human steering tightens input validation without changing scope	$expected_0001" "$lineage"
grep -Fqx "0000	-	initial frozen repository task	$expected_0000" "$thread"
grep -Fqx "0001	0000	human steering tightens input validation without changing scope	$expected_0001" "$thread"

if (
  cd "$root/task-repo"
  npm test >/dev/null 2>&1
); then
  echo "seed repository unexpectedly passes before implementation" >&2
  exit 1
fi

scratch="$(mktemp -d)"
cleanup() {
  rm -rf -- "$scratch"
}
trap cleanup EXIT
cp -a "$root/task-repo" "$scratch/candidate"
cp "$root/reference/report.mjs" "$scratch/candidate/src/report.mjs"
"$root/judges/judge-task.sh" "$scratch/candidate" >/dev/null
echo "TASK-CONTRACT-GREEN-43af"

if rg -n -i 'arm[-_ ]?[ab]|catalog[ -]?plan|direct[ -]?brief' \
  "$root/judges/judge-task.sh" "$root/judges/report.test.mjs"; then
  echo "arm-neutral correctness judge contains delivery-arm identity" >&2
  exit 1
fi
echo "ARM-PARITY-GREEN-43af"

matrix_output="$(CATALOG="$root" "$root/run-recovery-matrix.sh")"
grep -Fqx 'RECOVERY-GREEN-A-43af' <<<"$matrix_output"
grep -Fqx 'RECOVERY-GREEN-B-43af' <<<"$matrix_output"
echo "COLD-RESTART-GREEN-43af"
echo "LOCAL-PARTITION-GREEN-43af"
echo "HUMAN-STEERING-GREEN-43af"

test "$(awk -F '\t' 'NR > 1 && $4 == "gating" { count++ } END { print count + 0 }' "$measurements")" -eq 4
test "$(awk -F '\t' 'NR > 1 && $4 == "reporting" { count++ } END { print count + 0 }' "$measurements")" -eq 6
awk -F '\t' '
  NR > 1 && $4 == "gating" && $5 != "pass" { exit 1 }
  NR > 1 && $4 == "reporting" && $5 != "lower" { exit 1 }
' "$measurements"
test "$(awk -F '\t' 'NR > 1 && $3 != "yes" { count++ } END { print count + 0 }' "$receipts")" -eq 0
echo "MEASUREMENT-CONTRACT-GREEN-43af"

checked=0
while IFS=$'\t' read -r path expected; do
  if test "$path" = "path"; then
    test "$expected" = "sha256"
    continue
  fi
  if test "$path" = "task-repo.tree"; then
    test "$(tree_hash "$root/task-repo")" = "$expected"
    checked=$((checked + 1))
    continue
  fi
  test -f "$root/$path"
  actual="$(sha256sum "$root/$path" | awk '{print $1}')"
  test "$actual" = "$expected"
  checked=$((checked + 1))
done <"$root/provenance.tsv"
test "$checked" -eq 23
echo "PROVENANCE-GREEN-43af"

test "$(awk -F '\t' 'NR > 1 && $5 == "blocked" { count++ } END { print count + 0 }' "$blockers")" -eq 2
grep -Fq 'exact immutable source head' "$blockers"
grep -Fq 'reproducible binary path and SHA256' "$blockers"
grep -Fq 'separate authorization' "$blockers"
test -z "$(find "$root/arm-a" -type f -name '*.kdl' -print -quit)"
echo "PRODUCT-BLOCKERS-GREEN-43af"

if rg -n --pcre2 \
  '(^|[;&|][[:space:]]*)(claude|codex|curl|wget|ssh|gh|st2[[:space:]]+(up|eval|ping)|pty[[:space:]]+(run|send)|eval)[[:space:]]' \
  "$root" -g '*.sh' -g '*.kdl'; then
  echo "fixture contains a provider, network, product runtime, or nested eval command" >&2
  exit 1
fi
echo "HERMETIC-SCAFFOLD-GREEN-43af"
