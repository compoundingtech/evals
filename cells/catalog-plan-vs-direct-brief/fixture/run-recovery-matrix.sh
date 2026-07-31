#!/usr/bin/env bash
set -euo pipefail

root="${CATALOG:?CATALOG must be set}"
runner="$root/runner.tsv"
receipt="$root/comparison-receipt.json"
st2_path="$(command -v st2)"
scratch="$(mktemp -d)"

cleanup() {
  rm -rf -- "$scratch"
}
trap cleanup EXIT

runner_value() {
  awk -F '\t' -v key="$1" '$1 == key { print $2 }' "$runner"
}

hash_file() {
  sha256sum "$1" | awk '{print $1}'
}

assert_no_acceptance_claim() {
  jq -e '
    (has("accepted") | not) and
    (has("acceptance") | not) and
    (has("completed") | not) and
    (has("receipt") | not) and
    (has("receipts") | not)
  ' >/dev/null
}

source_full="$(runner_value source_full)"
source_short="$(runner_value source_short)"
expected_binary_sha="$(runner_value binary_sha256)"
version_regex="^st2 0\\.1\\.0 — running from local source \\(${source_short}, .+ ago\\)$"
actual_version="$($st2_path --version)"
actual_binary_sha="$(hash_file "$st2_path")"
[[ "$actual_version" =~ $version_regex ]]
test "$actual_binary_sha" = "$expected_binary_sha"

remote="$scratch/remote"
local_store="$scratch/local"
session="$scratch/session"
plan_local="$local_store/plan-catalog"
direct_bus="$local_store/direct-bus"
mkdir -p "$remote" "$local_store" "$session"
cp -a "$root/arm-a/catalog-initial" "$remote/plan-initial"
cp -a "$root/arm-a/catalog" "$remote/plan-steered"
cp -a "$root/arm-b/inbox" "$remote/direct-source"

# Initial delivery: sync only the initial plan snapshot, and deliver only the
# initial direct brief through the real st2 message store.
cp -a "$remote/plan-initial" "$plan_local"
initial_message="$($st2_path message send eval.worker \
  --catalog "$direct_bus" \
  --as eval.supervisor \
  --subject 'intent revision 0000' \
  <"$remote/direct-source/brief-0000.md")"
test -n "$initial_message"

# Cold restart and partition: volatile state disappears and both remote input
# sources go offline. Recovery must use only each arm's local durable store.
printf 'volatile\n' >"$session/state"
rm -rf -- "$session"
mv "$remote" "$remote.offline"
test ! -e "$remote"

plan_initial_show="$($st2_path plan show receipt-report --catalog "$plan_local" --json)"
plan_initial_inspect="$($st2_path plan inspect receipt-report --catalog "$plan_local" --json)"
jq -e '
  .frontier == ["0000"] and
  (.versions | length) == 1 and
  .versions[0].identity == "0000"
' <<<"$plan_initial_show" >/dev/null
plan_initial_path="$(jq -r '.versions[0].resolvedResource' <<<"$plan_initial_inspect")"
plan_initial_sha="$(hash_file "$plan_initial_path")"
test "$plan_initial_sha" = "$(hash_file "$root/arm-a/catalog-initial/plans/receipt-report/versions/0000.md")"
assert_no_acceptance_claim <<<"$plan_initial_show"
assert_no_acceptance_claim <<<"$plan_initial_inspect"

direct_initial_list="$($st2_path message ls eval.worker --catalog "$direct_bus" --json)"
jq -e --arg filename "$initial_message" '
  length == 1 and
  .[0].filename == $filename and
  .[0].from == "eval.supervisor" and
  .[0].subject == "intent revision 0000" and
  .[0].inReplyTo == null
' <<<"$direct_initial_list" >/dev/null
direct_initial_read="$($st2_path message read eval.worker "$initial_message" --catalog "$direct_bus" --json)"
jq -rj '.body' <<<"$direct_initial_read" >"$scratch/direct-initial.md"
direct_initial_sha="$(hash_file "$scratch/direct-initial.md")"
test "$direct_initial_sha" = "$(hash_file "$root/arm-b/inbox/brief-0000.md")"
assert_no_acceptance_claim <<<"$direct_initial_read"
echo "COLD-RESTART-TIE-43af"
echo "LOCAL-PARTITION-TIE-43af"

# Human steering: restore the remote source, sync a complete new plan snapshot,
# and deliver a reply-linked direct brief. Then repeat cold recovery offline.
mv "$remote.offline" "$remote"
rm -rf -- "$plan_local"
cp -a "$remote/plan-steered" "$plan_local"
steered_message="$($st2_path message send eval.worker \
  --catalog "$direct_bus" \
  --as eval.supervisor \
  --subject 'intent revision 0001' \
  --in-reply-to "$initial_message" \
  <"$remote/direct-source/brief-0001.md")"
test -n "$steered_message"

mkdir -p "$session"
printf 'volatile\n' >"$session/state"
rm -rf -- "$session"
mv "$remote" "$remote.offline"
test ! -e "$remote"

plan_steered_show="$($st2_path plan show receipt-report --catalog "$plan_local" --json)"
plan_steered_inspect="$($st2_path plan inspect receipt-report --catalog "$plan_local" --json)"
jq -e '
  .frontier == ["0001"] and
  (.versions | length) == 2 and
  .versions[0].identity == "0000" and
  .versions[1].identity == "0001" and
  .versions[1].parents == ["0000"]
' <<<"$plan_steered_show" >/dev/null
plan_steered_path="$(jq -r '.versions[] | select(.identity == "0001") | .resolvedResource' <<<"$plan_steered_inspect")"
plan_steered_sha="$(hash_file "$plan_steered_path")"
test "$plan_steered_sha" = "$(hash_file "$root/arm-a/catalog/plans/receipt-report/versions/0001.md")"
assert_no_acceptance_claim <<<"$plan_steered_show"
assert_no_acceptance_claim <<<"$plan_steered_inspect"

direct_steered_list="$($st2_path message ls eval.worker --catalog "$direct_bus" --json)"
jq -e --arg initial "$initial_message" --arg steered "$steered_message" '
  length == 2 and
  any(.[]; .filename == $initial and .inReplyTo == null) and
  any(.[]; .filename == $steered and .inReplyTo == $initial and .subject == "intent revision 0001")
' <<<"$direct_steered_list" >/dev/null
direct_steered_read="$($st2_path message read eval.worker "$steered_message" --catalog "$direct_bus" --json)"
jq -rj '.body' <<<"$direct_steered_read" >"$scratch/direct-steered.md"
direct_steered_sha="$(hash_file "$scratch/direct-steered.md")"
test "$direct_steered_sha" = "$(hash_file "$root/arm-b/inbox/brief-0001.md")"
test "$(jq -r '.inReplyTo' <<<"$direct_steered_read")" = "$initial_message"
assert_no_acceptance_claim <<<"$direct_steered_read"

test "$plan_initial_sha" = "$direct_initial_sha"
test "$plan_steered_sha" = "$direct_steered_sha"
echo "INTENT-RECOVERY-TIE-43af"
echo "HUMAN-STEERING-TIE-43af"
echo "ACCEPTANCE-EVIDENCE-TIE-43af"
echo "PLAN-STATIC-EVIDENCE-GREEN-43af"
echo "DIRECT-MESSAGE-EVIDENCE-GREEN-43af"

jq -n \
  --arg experiment_id "catalog-plan-vs-direct-brief-v1" \
  --arg source "$source_full" \
  --arg sha "$actual_binary_sha" \
  --arg initial_sha "$plan_initial_sha" \
  --arg steered_sha "$plan_steered_sha" \
  '{
    schemaVersion: 1,
    experimentId: $experiment_id,
    runner: {source: $source, sha256: $sha},
    modelCalls: 0,
    remoteSourcesOfflineDuringRecovery: true,
    storage: {plainFoldersSufficient: true, casRequired: false},
    arms: {
      A: {
        transport: "catalog-plan",
        initialIntentSha256: $initial_sha,
        steeredIntentSha256: $steered_sha
      },
      B: {
        transport: "st2-direct-messages",
        initialIntentSha256: $initial_sha,
        steeredIntentSha256: $steered_sha
      }
    },
    outcomes: {
      coldResume: {A: "pass", B: "pass", verdict: "tie"},
      intentRecovery: {A: "pass", B: "pass", verdict: "tie"},
      humanSteering: {A: "pass", B: "pass", verdict: "tie"},
      acceptanceEvidence: {
        A: "evaluator-only",
        B: "evaluator-only",
        verdict: "tie",
        reason: "Neither read-only plan inspection nor direct-message delivery reports worker acceptance."
      }
    },
    planOnly: {
      staticIntentValidation: "pass",
      provenanceResolution: "pass"
    },
    directOnly: {
      messageDelivery: "pass",
      replyLineage: "pass"
    },
    liveUnresolved: [
      "correctness",
      "coordination_messages",
      "coordination_bytes",
      "model_input_tokens",
      "model_output_tokens",
      "cost_usd",
      "wall_duration"
    ],
    conclusion: "no-measured-advantage"
  }' >"$receipt"

jq -e '
  .modelCalls == 0 and
  .remoteSourcesOfflineDuringRecovery == true and
  .storage.plainFoldersSufficient == true and
  .storage.casRequired == false and
  .outcomes.coldResume.verdict == "tie" and
  .outcomes.intentRecovery.verdict == "tie" and
  .outcomes.humanSteering.verdict == "tie" and
  .outcomes.acceptanceEvidence.verdict == "tie" and
  .planOnly.staticIntentValidation == "pass" and
  .planOnly.provenanceResolution == "pass" and
  .directOnly.messageDelivery == "pass" and
  .directOnly.replyLineage == "pass" and
  .conclusion == "no-measured-advantage"
' "$receipt" >/dev/null

echo "MODEL-FREE-COMPARISON-GREEN-43af"
echo "PLAIN-FOLDER-NO-CAS-GREEN-43af"
