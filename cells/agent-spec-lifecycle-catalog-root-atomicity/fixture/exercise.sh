#!/usr/bin/env bash
set -euo pipefail

results="$CATALOG/results"
network="$CATALOG/network"
mkdir -p \
  "$results" \
  "$network/agents/h/alpha/resources" \
  "$network/agents/h/beta/resources" \
  "$network/agents/h/gamma/resources"

capture() {
  local name=$1
  shift
  set +e
  "$@" >"$results/$name.json" 2>"$results/$name.err"
  local code=$?
  set -e
  printf '%s\n' "$code" >"$results/$name.code"
}

stage() {
  local name=$1 spec=$2 state=$3 operation=$4
  shift 4
  capture "$name" st2 --catalog "$network" catalog stage "$spec" \
    --manager nix \
    --state-relative "$state" \
    --operation-id "$operation" \
    "$@"
}

write_request() {
  local path=$1 expected=$2 operation=$3
  shift 3
  if test "$expected" = absent; then
    jq -n --arg operation "$operation" --args '$ARGS.positional' "$@" \
      | jq --arg operation "$operation" '{
          manager: "nix",
          operationId: $operation,
          selections: [range(0; length / 2) as $i | {
            refCommit: .[$i * 2],
            resourceBindingCommit: .[$i * 2 + 1]
          }]
        }' >"$path"
  else
    jq -n --arg expected "$expected" --arg operation "$operation" --args '$ARGS.positional' "$@" \
      | jq --arg expected "$expected" --arg operation "$operation" '{
          expectedRoot: $expected,
          manager: "nix",
          operationId: $operation,
          selections: [range(0; length / 2) as $i | {
            refCommit: .[$i * 2],
            resourceBindingCommit: .[$i * 2 + 1]
          }]
        }' >"$path"
  fi
}

alpha_base="$CATALOG/source/alpha-base/agents/h/alpha/agent.kdl"
beta_base="$CATALOG/source/beta-base/agents/h/beta/agent.kdl"
alpha_nix="$CATALOG/source/alpha-nix/agents/h/alpha/agent.kdl"
beta_nix="$CATALOG/source/beta-nix/agents/h/beta/agent.kdl"
gamma_dynamic="$CATALOG/source/gamma-dynamic/agents/h/gamma/agent.kdl"

stage alpha-base "$alpha_base" agents/h/alpha alpha-base
stage beta-base "$beta_base" agents/h/beta beta-base
alpha_ref0=$(jq -er .refCommit "$results/alpha-base.json")
alpha_binding0=$(jq -er .resourceBindingCommit "$results/alpha-base.json")
beta_ref0=$(jq -er .refCommit "$results/beta-base.json")
beta_binding0=$(jq -er .resourceBindingCommit "$results/beta-base.json")

write_request "$results/base-request.json" absent admit-base \
  "$alpha_ref0" "$alpha_binding0" "$beta_ref0" "$beta_binding0"
capture admit-base st2 --catalog "$network" catalog admit "$results/base-request.json"
root0=$(jq -er .rootCommit "$results/admit-base.json")
capture inspect-base st2 --catalog "$network" catalog inspect

stage alpha-nix "$alpha_nix" agents/h/alpha alpha-nix \
  --expected-ref "$alpha_ref0" --binding-parent "$alpha_binding0"
stage beta-nix "$beta_nix" agents/h/beta beta-nix \
  --expected-ref "$beta_ref0" --binding-parent "$beta_binding0"
alpha_ref1=$(jq -er .refCommit "$results/alpha-nix.json")
alpha_binding1=$(jq -er .resourceBindingCommit "$results/alpha-nix.json")
beta_ref1=$(jq -er .refCommit "$results/beta-nix.json")
beta_binding1=$(jq -er .resourceBindingCommit "$results/beta-nix.json")
capture head-after-stage st2 --catalog "$network" catalog head

# Both commits exist, but they belong to different seats and cannot be joined.
write_request "$results/invalid-request.json" "$root0" admit-invalid \
  "$alpha_ref1" "$beta_binding1"
capture invalid st2 --catalog "$network" catalog admit "$results/invalid-request.json"
capture head-after-invalid st2 --catalog "$network" catalog head

write_request "$results/nix-request.json" "$root0" admit-nix \
  "$alpha_ref1" "$alpha_binding1" "$beta_ref1" "$beta_binding1"

# Sample the public root while the whole two-seat admission is published.
: >"$results/observed-heads.jsonl"
(
  while test ! -e "$results/poll-stop"; do
    st2 --catalog "$network" catalog head \
      >>"$results/observed-heads.jsonl" 2>/dev/null || true
  done
) &
poller=$!
capture admit-nix st2 --catalog "$network" catalog admit "$results/nix-request.json"
touch "$results/poll-stop"
wait "$poller"
capture head-final st2 --catalog "$network" catalog head
capture inspect-final st2 --catalog "$network" catalog inspect
cat "$results/head-final.json" >>"$results/observed-heads.jsonl"
root1=$(jq -er .rootCommit "$results/admit-nix.json")

surface=false
if test "$(cat "$results/admit-base.code")" = 0 \
  && test "$(jq -r .seats "$results/admit-base.json")" = 2 \
  && test "$(jq -r '.seats | length' "$results/inspect-base.json")" = 2; then
  surface=true
fi

invalid_graph_rejected=false
if test "$(cat "$results/invalid.code")" != 0 \
  && test "$(jq -er .commit "$results/head-after-invalid.json")" = "$root0"; then
  invalid_graph_rejected=true
fi

nix_patch_one_root=false
if test "$(cat "$results/admit-nix.code")" = 0 \
  && test "$root1" != "$root0" \
  && test "$(jq -er .commit "$results/head-final.json")" = "$root1" \
  && test "$(jq -er .value.parent "$results/head-final.json")" = "$root0" \
  && test "$(jq -r '.value.admissions | length' "$results/head-final.json")" = 2 \
  && test "$(jq -r .seats "$results/admit-nix.json")" = 2; then
  nix_patch_one_root=true
fi

no_mixed_snapshot=false
if jq -s -e --arg old "$root0" --arg new "$root1" \
  'length > 0 and all(.[]; .commit == $old or .commit == $new)
   and any(.[]; .commit == $new)' \
  "$results/observed-heads.jsonl" >/dev/null; then
  no_mixed_snapshot=true
fi

# A root transaction records its actor but does not take custody of every seat.
# A dynamic manager can append its own seat while each ref remains manager-owned.
capture gamma-dynamic st2 --catalog "$network" catalog stage "$gamma_dynamic" \
  --manager dynamic \
  --state-relative agents/h/gamma \
  --operation-id gamma-dynamic
gamma_ref=$(jq -er .refCommit "$results/gamma-dynamic.json")
gamma_binding=$(jq -er .resourceBindingCommit "$results/gamma-dynamic.json")

# The original base root is now genuinely stale. This otherwise-valid dynamic
# seat must not cross the newer Nix root.
jq -n \
  --arg expected "$root0" \
  --arg ref "$gamma_ref" \
  --arg binding "$gamma_binding" \
  '{
    expectedRoot: $expected,
    manager: "dynamic",
    operationId: "admit-dynamic-stale",
    selections: [{
      refCommit: $ref,
      resourceBindingCommit: $binding
    }]
  }' >"$results/stale-request.json"
capture stale st2 --catalog "$network" catalog admit "$results/stale-request.json"
capture head-after-stale st2 --catalog "$network" catalog head

capture dynamic-moves-nix st2 --catalog "$network" catalog stage "$alpha_nix" \
  --manager dynamic \
  --state-relative agents/h/alpha \
  --operation-id dynamic-moves-nix \
  --expected-ref "$alpha_ref1" \
  --binding-parent "$alpha_binding1"
capture nix-moves-dynamic st2 --catalog "$network" catalog stage "$gamma_dynamic" \
  --manager nix \
  --state-relative agents/h/gamma \
  --operation-id nix-moves-dynamic \
  --expected-ref "$gamma_ref" \
  --binding-parent "$gamma_binding"

jq -n \
  --arg expected "$root1" \
  --arg ref "$gamma_ref" \
  --arg binding "$gamma_binding" \
  '{
    expectedRoot: $expected,
    manager: "dynamic",
    operationId: "admit-dynamic",
    selections: [{
      refCommit: $ref,
      resourceBindingCommit: $binding
    }]
  }' >"$results/dynamic-request.json"
capture admit-dynamic st2 --catalog "$network" catalog admit "$results/dynamic-request.json"
capture head-dynamic st2 --catalog "$network" catalog head
capture inspect-dynamic st2 --catalog "$network" catalog inspect
root2=$(jq -er .rootCommit "$results/admit-dynamic.json")

stale_root_rejected=false
if test "$(cat "$results/stale.code")" != 0 \
  && test "$(jq -er .commit "$results/head-after-stale.json")" = "$root1"; then
  stale_root_rejected=true
fi

mixed_managers_preserved=false
if test "$(cat "$results/gamma-dynamic.code")" = 0 \
  && test "$(cat "$results/dynamic-moves-nix.code")" != 0 \
  && test "$(cat "$results/nix-moves-dynamic.code")" != 0 \
  && test "$(cat "$results/admit-dynamic.code")" = 0 \
  && test "$(jq -er .value.parent "$results/head-dynamic.json")" = "$root1" \
  && test "$(jq -r '.value.admissions | length' "$results/head-dynamic.json")" = 3 \
  && test "$(jq -er '.value.admissions["h.alpha"]' "$results/head-dynamic.json")" = \
    "$(jq -er '.value.admissions["h.alpha"]' "$results/head-final.json")" \
  && test "$(jq -er '.value.admissions["h.beta"]' "$results/head-dynamic.json")" = \
    "$(jq -er '.value.admissions["h.beta"]' "$results/head-final.json")" \
  && test "$(jq -Sc '.seats[] | select(.busId == "h.alpha")' "$results/inspect-dynamic.json")" = \
    "$(jq -Sc '.seats[] | select(.busId == "h.alpha")' "$results/inspect-final.json")" \
  && test "$(jq -Sc '.seats[] | select(.busId == "h.beta")' "$results/inspect-dynamic.json")" = \
    "$(jq -Sc '.seats[] | select(.busId == "h.beta")' "$results/inspect-final.json")"; then
  mixed_managers_preserved=true
fi

# Corruption is observable through the supported resolver. Preserve the head,
# corrupt one admitted object, and require inspect to reject the graph.
object_path=$(jq -er '.seats[] | select(.busId == "h.alpha") | .sourcePath' \
  "$results/inspect-dynamic.json")
chmod u+w "$object_path"
printf 'corrupt\n' >"$object_path"
capture inspect-corrupt st2 --catalog "$network" catalog inspect
capture head-after-corrupt st2 --catalog "$network" catalog head
corruption_rejected=false
if test "$(cat "$results/inspect-corrupt.code")" != 0 \
  && test "$(jq -er .commit "$results/head-after-corrupt.json")" = "$root2"; then
  corruption_rejected=true
fi

jq -n \
  --argjson surface "$surface" \
  --argjson stale "$stale_root_rejected" \
  --argjson invalid "$invalid_graph_rejected" \
  --argjson patch "$nix_patch_one_root" \
  --argjson mixed "$no_mixed_snapshot" \
  --argjson managers "$mixed_managers_preserved" \
  --argjson corruption "$corruption_rejected" \
  '{
    surface: $surface,
    staleRootRejected: $stale,
    invalidGraphRejected: $invalid,
    nixPatchOneRoot: $patch,
    noMixedSnapshot: $mixed,
    mixedManagersPreserved: $managers,
    corruptionRejected: $corruption
  }' >"$results/outcomes.json"
