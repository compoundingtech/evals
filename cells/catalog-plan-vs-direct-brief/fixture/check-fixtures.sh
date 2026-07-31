#!/usr/bin/env bash
set -euo pipefail

root="${CATALOG:?CATALOG must be set}"
experiment="$root/experiment.tsv"
arms="$root/arms.tsv"
scenario="$root/scenario.tsv"
measurements="$root/measurement-schema.tsv"
receipts="$root/receipt-schema.tsv"
blockers="$root/blockers.tsv"
runner="$root/runner.tsv"
plan_declaration="$root/arm-a/catalog/plans/receipt-report/plan.kdl"
agent_declaration="$root/arm-a/catalog/agents/eval/receipt-worker/agent.kdl"
initial_plan_declaration="$root/arm-a/catalog-initial/plans/receipt-report/plan.kdl"
initial_agent_declaration="$root/arm-a/catalog-initial/agents/eval/receipt-worker/agent.kdl"
initial_plan_0000="$root/arm-a/catalog-initial/plans/receipt-report/versions/0000.md"
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
expect_header "$arms" $'arm\tinput_kind\tinitial_source\tlocal_resume_source\tsteering_source\tacceptance_surface\tallowed_tools\twall_budget_seconds\tmodel_token_budget\tjudge_profile\tdone_condition'
expect_header "$scenario" $'ordinal\tevent\tarm_a_input\tarm_b_input\tinvariant'
expect_header "$measurements" $'metric\ttype\tunit\trole\tpreferred_direction\tmodel_free_arm_a\tmodel_free_arm_b\tmodel_free_verdict\tlive_source'
expect_header "$receipts" $'field\ttype\trequired\tdescription'
expect_header "$blockers" $'blocker_id\towner\tdependency\trequired_evidence\tstatus'
expect_header "$runner" $'field\tvalue'

test "$(awk -F '\t' 'NR > 1 { count++ } END { print count + 0 }' "$arms")" -eq 2
test "$(awk -F '\t' 'NR > 1 { count++ } END { print count + 0 }' "$scenario")" -eq 6
test "$(awk -F '\t' 'NR > 1 { count++ } END { print count + 0 }' "$measurements")" -eq 14
test "$(awk -F '\t' 'NR > 1 { count++ } END { print count + 0 }' "$receipts")" -eq 24
test "$(awk -F '\t' 'NR > 1 { count++ } END { print count + 0 }' "$blockers")" -eq 2
test "$(awk -F '\t' 'NR > 1 { count++ } END { print count + 0 }' "$runner")" -eq 8

grep -Fqx $'allowed_tools\tnode,bash,git' "$experiment"
grep -Fqx $'network_policy\tdisabled' "$experiment"
grep -Fqx $'wall_budget_seconds\t1200' "$experiment"
grep -Fqx $'model_token_budget\t40000' "$experiment"
grep -Fqx $'initial_revision\t0000' "$experiment"
grep -Fqx $'steering_revision\t0001' "$experiment"
grep -Fqx $'model_free_result\tno-measured-advantage-for-cold-resume-intent-recovery-or-acceptance-evidence' "$experiment"
grep -Fqx $'source_gist\thttps://gist.github.com/myobie/d5ecfac24cd3965e095a5031cd2e00cb/5c1d1427c0556d95d13890e5c5086cd85b25d994' "$experiment"
grep -Fqx $'source_gist_revision\t5c1d1427c0556d95d13890e5c5086cd85b25d994' "$experiment"
grep -Fqx $'st2_plan_source\t60d48bae5b7ac3a83c8d2c3324b61680bd6404dd' "$experiment"
grep -Fqx $'st2_plan_binary_sha256\tf3e935ee8e6c38b5ba29f0507b4639fe2212e3764b43e18967f6762a5962e48a' "$experiment"
grep -Fqx $'live_run_status\tblocked-pending-separate-provider-authorization' "$experiment"
grep -Fqx $'st2_pr\thttps://github.com/compoundingtech/st2/pull/115' "$runner"
grep -Fqx $'source_full\t60d48bae5b7ac3a83c8d2c3324b61680bd6404dd' "$runner"
grep -Fqx $'source_short\t60d48ba' "$runner"
grep -Fqx $'binary_sha256\tf3e935ee8e6c38b5ba29f0507b4639fe2212e3764b43e18967f6762a5962e48a' "$runner"
grep -Fqx $'source_gist_revision\t5c1d1427c0556d95d13890e5c5086cd85b25d994' "$runner"
grep -Fqx $'runtime_scope\tread-only-validate-list-show-inspect' "$runner"
grep -Fqx $'hosted_run\thttps://github.com/compoundingtech/st2/actions/runs/30666101129' "$runner"
grep -Fqx $'hosted_status\tpass' "$runner"

cmp -s "$initial_plan_0000" "$plan_0000"
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
grep -Fqx $'A\tversioned-catalog-plan\tarm-a/catalog-initial/plans/receipt-report/versions/0000.md\tlocal plan catalog inspected through st2 plan\tarm-a/catalog/plans/receipt-report/versions/0001.md\tevaluator-owned receipt only\tnode,bash,git\t1200\t40000\tarm-neutral-public-plus-held-out\tpublic and held-out tests pass; only src/report.mjs differs from the seed; no dependency or network change' "$arms"
grep -Fqx $'B\tdurable-direct-brief\tarm-b/inbox/brief-0000.md\tlocal st2 message inbox read through st2 message\tarm-b/inbox/brief-0001.md\tevaluator-owned receipt only\tnode,bash,git\t1200\t40000\tarm-neutral-public-plus-held-out\tpublic and held-out tests pass; only src/report.mjs differs from the seed; no dependency or network change' "$arms"

grep -Fqx 'plan "receipt-report" {' "$plan_declaration"
grep -Fqx '  owner "receipt-worker"' "$plan_declaration"
grep -Fqx '  version "0000" resource="file:versions/0000.md"' "$plan_declaration"
grep -Fqx '  version "0001" resource="file:versions/0001.md" {' "$plan_declaration"
grep -Fqx '    parent "0000"' "$plan_declaration"
grep -Fqx '    why "Human steering tightens input validation without changing scope."' "$plan_declaration"
grep -Fqx 'plan "receipt-report" {' "$initial_plan_declaration"
grep -Fqx '  owner "receipt-worker"' "$initial_plan_declaration"
grep -Fqx '  version "0000" resource="file:versions/0000.md"' "$initial_plan_declaration"
if grep -Fq 'version "0001"' "$initial_plan_declaration"; then
  echo "initial plan snapshot already contains the steering revision" >&2
  exit 1
fi
grep -Fqx 'agent "receipt-worker" {' "$agent_declaration"
grep -Fqx '  plan-ref "file:../../../plans/receipt-report/plan.kdl"' "$agent_declaration"
cmp -s "$initial_agent_declaration" "$agent_declaration"

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
for marker in \
  COLD-RESTART-TIE-43af \
  LOCAL-PARTITION-TIE-43af \
  INTENT-RECOVERY-TIE-43af \
  HUMAN-STEERING-TIE-43af \
  ACCEPTANCE-EVIDENCE-TIE-43af \
  PLAN-STATIC-EVIDENCE-GREEN-43af \
  DIRECT-MESSAGE-EVIDENCE-GREEN-43af \
  MODEL-FREE-COMPARISON-GREEN-43af \
  PLAIN-FOLDER-NO-CAS-GREEN-43af; do
  grep -Fqx "$marker" <<<"$matrix_output"
done
jq -e '
  .outcomes.coldResume.verdict == "tie" and
  .outcomes.intentRecovery.verdict == "tie" and
  .outcomes.humanSteering.verdict == "tie" and
  .outcomes.acceptanceEvidence.verdict == "tie" and
  .conclusion == "no-measured-advantage"
' "$root/comparison-receipt.json" >/dev/null
echo "COLD-RESTART-TIE-43af"
echo "LOCAL-PARTITION-TIE-43af"
echo "INTENT-RECOVERY-TIE-43af"
echo "HUMAN-STEERING-TIE-43af"
echo "ACCEPTANCE-EVIDENCE-TIE-43af"
echo "PLAN-STATIC-EVIDENCE-GREEN-43af"
echo "DIRECT-MESSAGE-EVIDENCE-GREEN-43af"
echo "PLAIN-FOLDER-NO-CAS-GREEN-43af"
echo "MODEL-FREE-OUTCOME-GREEN-43af"

test "$(awk -F '\t' 'NR > 1 && $4 == "model-free-gating" { count++ } END { print count + 0 }' "$measurements")" -eq 3
test "$(awk -F '\t' 'NR > 1 && $4 == "live-gating" { count++ } END { print count + 0 }' "$measurements")" -eq 2
test "$(awk -F '\t' 'NR > 1 && $4 == "reporting" { count++ } END { print count + 0 }' "$measurements")" -eq 3
test "$(awk -F '\t' 'NR > 1 && $4 == "live-reporting" { count++ } END { print count + 0 }' "$measurements")" -eq 6
awk -F '\t' '
  NR > 1 && ($4 == "model-free-gating" || $4 == "live-gating" || $4 == "reporting") && $5 != "pass" && $1 != "acceptance_evidence" { exit 1 }
  NR > 1 && $4 == "live-reporting" && $5 != "lower" { exit 1 }
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
expected_provenance="$(awk -F '\t' 'NR > 1 { count++ } END { print count + 0 }' "$root/provenance.tsv")"
test "$checked" -eq "$expected_provenance"
echo "PROVENANCE-GREEN-43af"

test "$(awk -F '\t' 'NR > 1 && $5 == "ready" { count++ } END { print count + 0 }' "$blockers")" -eq 1
test "$(awk -F '\t' 'NR > 1 && $5 == "blocked" { count++ } END { print count + 0 }' "$blockers")" -eq 1
grep -Fq '60d48bae5b7ac3a83c8d2c3324b61680bd6404dd' "$blockers"
grep -Fq 'f3e935ee8e6c38b5ba29f0507b4639fe2212e3764b43e18967f6762a5962e48a' "$blockers"
grep -Fq 'hosted run 30666101129 green' "$blockers"
grep -Fq 'separate authorization' "$blockers"
test "$(find "$root/arm-a" -type f -name '*.kdl' | wc -l)" -eq 4
echo "PRODUCT-PAIRING-GREEN-43af"

if rg -n --pcre2 \
  '(^|[;&|][[:space:]]*)(claude|codex|curl|wget|ssh|gh|st2[[:space:]]+(up|eval|ping)|pty[[:space:]]+(run|send)|eval)[[:space:]]' \
  "$root" -g '*.sh' -g '*.kdl'; then
  echo "fixture contains a provider, network, mutating product runtime, or nested eval command" >&2
  exit 1
fi
echo "HERMETIC-SCAFFOLD-GREEN-43af"
