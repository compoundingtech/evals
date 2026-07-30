#!/usr/bin/env bash
set -euo pipefail

fixture_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cases="$fixture_root/cases.tsv"
hook_cases="$fixture_root/hook-cases.tsv"
providers="$fixture_root/providers.tsv"
ab_cases="$fixture_root/ab-cases.tsv"
input_race_cases="$fixture_root/input-race-cases.tsv"
provenance="$fixture_root/provenance.tsv"
blockers="$fixture_root/blockers.tsv"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

header="$(head -n 1 "$cases")"
[ "$header" = $'case_id\tscreen_fixture\texpected_activity\tdiagnostic_case\tauthority' ] ||
  fail "cases.tsv header changed"

expected_cases=(
  active-turn
  alternate-screen
  clear
  compaction
  crash
  idle-prompt
  long-child
  raw-mode
  restore
)
mapfile -t actual_cases < <(tail -n +2 "$cases" | cut -f1 | LC_ALL=C sort)
[ "${actual_cases[*]}" = "${expected_cases[*]}" ] ||
  fail "case IDs differ from the reviewed nine-case matrix"
[ "$(printf '%s\n' "${actual_cases[@]}" | uniq -d | wc -l)" -eq 0 ] ||
  fail "duplicate case ID"

provenance_header="$(head -n 1 "$provenance")"
[ "$provenance_header" = $'asset_id\tkind\tcase_id\tproduct\tsource\tschema_version\tderivation\tredaction_review\tsha256\towner\tstatus\texpected_result' ] ||
  fail "provenance.tsv header changed"
[ -z "$(tail -n +2 "$provenance" | cut -f1 | LC_ALL=C sort | uniq -d)" ] ||
  fail "duplicate provenance asset ID"

provider_header="$(head -n 1 "$providers")"
[ "$provider_header" = $'adapter_id\tfixture_owner\tactivity_status\thook_status' ] ||
  fail "providers.tsv header changed"
mapfile -t adapter_ids < <(tail -n +2 "$providers" | cut -f1 | LC_ALL=C sort)
[ "${#adapter_ids[@]}" -eq 2 ] || fail "expected two maintained provider fixture inventories"
[ -z "$(printf '%s\n' "${adapter_ids[@]}" | uniq -d)" ] ||
  fail "duplicate adapter fixture ID"
while IFS=$'\t' read -r adapter_id fixture_owner activity_status hook_status; do
  [ "$adapter_id" != "adapter_id" ] || continue
  [ -n "$adapter_id" ] && [ -n "$fixture_owner" ] ||
    fail "provider fixture inventory omits identity or owner"
  [ "$activity_status" = "blocked" ] && [ "$hook_status" = "blocked" ] ||
    fail "$adapter_id claims fixtures before reviewed artifacts exist"
done <"$providers"

screen_count=0
provider_count=0
while IFS=$'\t' read -r case_id screen expected_activity diagnostic authority; do
  [ "$case_id" != "case_id" ] || continue
  case "$expected_activity" in
    unknown|active|child_command|idle) ;;
    *) fail "$case_id has invalid generic expected activity $expected_activity" ;;
  esac
  [ "$authority" = "live-activity-only" ] ||
    fail "$case_id makes a diagnostic fixture authoritative"
  [ -n "$diagnostic" ] || fail "$case_id omits its diagnostic classification"

  screen_path="$fixture_root/$screen"
  [ -f "$screen_path" ] || fail "$case_id screen is missing: $screen"
  if ! LC_ALL=C tr -d '\11\12\15\40-\176' <"$screen_path" | cmp -s - /dev/null; then
    fail "$case_id screen is not stable ASCII"
  fi
  row="$(awk -F '\t' -v id="screen/$case_id" '$1 == id { print }' "$provenance")"
  [ -n "$row" ] || fail "$case_id screen has no provenance row"
  IFS=$'\t' read -r asset_id kind row_case product source schema derivation redaction expected_hash owner status row_activity <<<"$row"
  [ "$asset_id" = "screen/$case_id" ] &&
    [ "$kind" = "ascii-screen" ] &&
    [ "$row_case" = "$case_id" ] &&
    [ "$product" = "generic" ] &&
    [ "$source" = "evals#57" ] &&
    [ "$schema" = "diagnostic-ascii-v1" ] &&
    [ "$derivation" = "synthetic" ] &&
    [ "$redaction" = "not-required-synthetic" ] &&
    [ "$owner" = "evals" ] &&
    [ "$status" = "ready" ] &&
    [ "$row_activity" = "$expected_activity" ] ||
      fail "$case_id screen provenance is incomplete"
  [ "$(sha256sum "$screen_path" | cut -d' ' -f1)" = "$expected_hash" ] ||
    fail "$case_id screen hash differs from provenance"
  ((screen_count += 1))

  for provider in "${adapter_ids[@]}"; do
    provider_row="$(awk -F '\t' -v id="$provider/$case_id" '$1 == id { print }' "$provenance")"
    [ -n "$provider_row" ] || fail "$provider/$case_id slot is missing"
    IFS=$'\t' read -r provider_asset provider_kind provider_case provider_name provider_source provider_schema provider_derivation provider_redaction provider_hash provider_owner provider_status provider_activity <<<"$provider_row"
    [ "$provider_asset" = "$provider/$case_id" ] &&
      [ "$provider_kind" = "adapter-event" ] &&
      [ "$provider_case" = "$case_id" ] &&
      [ "$provider_name" = "$provider" ] &&
      [ "$provider_source" = "pending-owner-artifact" ] &&
      [ "$provider_schema" = "pending" ] &&
      [ "$provider_derivation" = "none" ] &&
      [ "$provider_redaction" = "pending" ] &&
      [ "$provider_hash" = "-" ] &&
      [ "$provider_owner" = "pending" ] &&
      [ "$provider_status" = "blocked" ] &&
      [ "$provider_activity" = "$expected_activity" ] ||
        fail "$provider/$case_id slot invents or omits provenance"
    ((provider_count += 1))
  done
done <"$cases"

[ "$screen_count" -eq 9 ] || fail "expected nine screen fixtures"
[ "$provider_count" -eq $((screen_count * ${#adapter_ids[@]})) ] ||
  fail "expected symmetric activity fixture slots for every provider"

hook_header="$(head -n 1 "$hook_cases")"
[ "$hook_header" = $'case_id\texpected_outcome\tauthority' ] ||
  fail "hook-cases.tsv header changed"
expected_hook_cases=(
  hook-failure
  post-turn-empty
  post-turn-multiple
  post-turn-unread
)
mapfile -t actual_hook_cases < <(tail -n +2 "$hook_cases" | cut -f1 | LC_ALL=C sort)
[ "${actual_hook_cases[*]}" = "${expected_hook_cases[*]}" ] ||
  fail "post-turn hook case IDs differ from the reviewed matrix"

hook_slot_count=0
while IFS=$'\t' read -r hook_case expected_outcome authority; do
  [ "$hook_case" != "case_id" ] || continue
  [ "$authority" = "durable-inbox-only" ] ||
    fail "$hook_case does not preserve durable-inbox authority"
  for provider in "${adapter_ids[@]}"; do
    hook_row="$(awk -F '\t' -v id="$provider/hook/$hook_case" '$1 == id { print }' "$provenance")"
    [ -n "$hook_row" ] || fail "$provider/hook/$hook_case slot is missing"
    IFS=$'\t' read -r hook_asset hook_kind row_case row_product hook_source hook_schema hook_derivation hook_redaction hook_hash hook_owner hook_status hook_outcome <<<"$hook_row"
    [ "$hook_asset" = "$provider/hook/$hook_case" ] &&
      [ "$hook_kind" = "post-turn-hook" ] &&
      [ "$row_case" = "$hook_case" ] &&
      [ "$row_product" = "$provider" ] &&
      [ "$hook_source" = "pending-owner-artifact" ] &&
      [ "$hook_schema" = "pending" ] &&
      [ "$hook_derivation" = "none" ] &&
      [ "$hook_redaction" = "pending" ] &&
      [ "$hook_hash" = "-" ] &&
      [ "$hook_owner" = "pending" ] &&
      [ "$hook_status" = "blocked" ] &&
      [ "$hook_outcome" = "$expected_outcome" ] ||
        fail "$provider/hook/$hook_case slot invents or omits provenance"
    ((hook_slot_count += 1))
  done
done <"$hook_cases"
[ "$hook_slot_count" -eq $((${#actual_hook_cases[@]} * ${#adapter_ids[@]})) ] ||
  fail "expected symmetric post-turn hook slots for every provider"

ab_header="$(head -n 1 "$ab_cases")"
[ "$ab_header" = $'case_id\ta_delivery\tb_delivery\tdurable_expectation\tfifo_expectation\tmodel_calls\tb_pty_bytes\tb_collision_goal' ] ||
  fail "ab-cases.tsv header changed"
expected_ab_cases=(
  active-turn
  compaction-clear
  crash-restart
  dnd
  fifo-burst
  hook-failure
  idle
  long-child
  stale-unknown
)
mapfile -t actual_ab_cases < <(tail -n +2 "$ab_cases" | cut -f1 | LC_ALL=C sort)
[ "${actual_ab_cases[*]}" = "${expected_ab_cases[*]}" ] ||
  fail "A/B case IDs differ from the authorized matrix"
while IFS=$'\t' read -r ab_case a_delivery b_delivery durable fifo model_calls b_bytes collision_goal; do
  [ "$ab_case" != "case_id" ] || continue
  [ -n "$a_delivery" ] && [ -n "$b_delivery" ] ||
    fail "$ab_case omits an A or B delivery expectation"
  [ "$durable" = "eventual-exactly-once" ] &&
    [ "$fifo" = "preserve" ] &&
    [ "$model_calls" = "0" ] &&
    [ "$collision_goal" = "zero" ] ||
      fail "$ab_case biases or weakens the shared durability/cost/collision contract"
done <"$ab_cases"
active_b="$(awk -F '\t' '$1 == "active-turn" { print $3 "\t" $7 }' "$ab_cases")"
[ "$active_b" = $'next-hook-context\tzero' ] ||
  fail "active-turn B must write zero PTY bytes and deliver through the next hook context"
idle_b="$(awk -F '\t' '$1 == "idle" { print $3 "\t" $7 }' "$ab_cases")"
[ "$idle_b" = $'bounded-idle-wake\texactly-one' ] ||
  fail "idle B must permit exactly one bounded wake"

input_header="$(head -n 1 "$input_race_cases")"
[ "$input_header" = $'case_id\tadapter_precondition\tconcurrent_change\texpected_ding_bytes\texpected_candidate_result\tauthority_dependency' ] ||
  fail "input-race-cases.tsv header changed"
expected_input_cases=(
  attached-viewer-no-io
  escape-race
  newline-race
  output-race
  partial-command
  paste-race
  quiet-no-viewer
  recent-key
  restart-race
  supervisor-input-race
)
mapfile -t actual_input_cases < <(tail -n +2 "$input_race_cases" | cut -f1 | LC_ALL=C sort)
[ "${actual_input_cases[*]}" = "${expected_input_cases[*]}" ] ||
  fail "conditional-send cases differ from the authorized generic race matrix"
while IFS=$'\t' read -r input_case adapter_precondition concurrent_change expected_bytes candidate_result dependency; do
  [ "$input_case" != "case_id" ] || continue
  [ -n "$adapter_precondition" ] && [ -n "$concurrent_change" ] && [ -n "$dependency" ] ||
    fail "$input_case omits generic conditional-send evidence"
  case "$candidate_result" in
    accept)
      [ "$concurrent_change" = "none" ] && [ "$expected_bytes" = "exactly-one" ] ||
        fail "$input_case accepts after an I/O race"
      ;;
    reject|reject-before-candidate|reject-ding-candidate)
      [ "$expected_bytes" = "zero" ] ||
        fail "$input_case rejection still permits DING bytes"
      ;;
    *) fail "$input_case has unsupported candidate outcome $candidate_result" ;;
  esac
done <"$input_race_cases"

[ ! -e "$fixture_root/provider-payloads" ] ||
  fail "provider payload exists before reviewed fixture delivery"

blocker_header="$(head -n 1 "$blockers")"
[ "$blocker_header" = $'blocker_id\towner\tdependency\trequired_evidence\tstatus' ] ||
  fail "blockers.tsv header changed"
blocker_count=0
while IFS=$'\t' read -r blocker_id owner dependency evidence status; do
  [ "$blocker_id" != "blocker_id" ] || continue
  [ -n "$blocker_id" ] && [ -n "$owner" ] && [ -n "$dependency" ] && [ -n "$evidence" ] ||
    fail "incomplete blocker row"
  case "$status" in
    pending|blocked) ;;
    *) fail "$blocker_id has unsupported blocker status $status" ;;
  esac
  ((blocker_count += 1))
done <"$blockers"
[ "$blocker_count" -eq 7 ] || fail "expected seven explicit product/fixture blockers"

echo "DIAGNOSTIC-FIXTURES-GREEN-57d1"
echo "PROVIDER-SLOTS-GREEN-57d1"
echo "AB-INVENTORY-GREEN-57d1"
echo "CONDITIONAL-SEND-INVENTORY-GREEN-57d1"
echo "PROVENANCE-INVENTORY-GREEN-57d1"
echo "PRODUCT-BLOCKERS-GREEN-57d1"
echo "HERMETIC-SKELETON-GREEN-57d1"
