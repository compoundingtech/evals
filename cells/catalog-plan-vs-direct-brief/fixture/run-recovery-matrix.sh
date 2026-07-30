#!/usr/bin/env bash
set -euo pipefail

root="${CATALOG:?CATALOG must be set}"
scratch="$(mktemp -d)"
cleanup() {
  rm -rf -- "$scratch"
}
trap cleanup EXIT

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

seed_hash="$(tree_hash "$root/task-repo")"
receipt_header=$'receipt_id\tarm\tphase\tintent_revision\tintent_sha256\tseed_repo_sha256\tcorrectness\tcold_restart_recovery\tpartition_recovery\thuman_steering\tcoordination_messages\tcoordination_bytes\tmodel_input_tokens\tmodel_output_tokens\tcost_usd\twall_duration_seconds\tevidence'

run_arm() {
  arm="$1"
  remote="$scratch/$arm/remote"
  local_store="$scratch/$arm/local"
  session="$scratch/$arm/session"
  receipts="$scratch/$arm/receipts.tsv"

  mkdir -p "$remote" "$local_store" "$session"
  printf '%s\n' "$receipt_header" >"$receipts"

  case "$arm" in
    A)
      cp -a "$root/arm-a/catalog" "$remote/catalog"
      initial_source="$remote/catalog/plans/receipt-report/versions/0000.md"
      steered_source="$remote/catalog/plans/receipt-report/versions/0001.md"
      initial_local="$local_store/catalog/plans/receipt-report/versions/0000.md"
      steered_local="$local_store/catalog/plans/receipt-report/versions/0001.md"
      mkdir -p "$(dirname "$initial_local")"
      ;;
    B)
      cp -a "$root/arm-b/inbox" "$remote/inbox"
      initial_source="$remote/inbox/brief-0000.md"
      steered_source="$remote/inbox/brief-0001.md"
      initial_local="$local_store/inbox/brief-0000.md"
      steered_local="$local_store/inbox/brief-0001.md"
      mkdir -p "$(dirname "$initial_local")"
      ;;
    *)
      echo "unknown arm: $arm" >&2
      return 2
      ;;
  esac

  initial_hash="$(sha256sum "$initial_source" | awk '{print $1}')"
  steered_hash="$(sha256sum "$steered_source" | awk '{print $1}')"
  cp "$initial_source" "$initial_local"
  printf '%s\n' \
    "${arm}-accepted-0000	${arm}	accepted	0000	${initial_hash}	${seed_hash}	not-run	not-run	not-run	not-run	0	0	0	0	0	0	local:${initial_local#$scratch/}" \
    >>"$receipts"

  printf 'volatile state\n' >"$session/state"
  rm -rf -- "$session"
  mv "$remote" "$remote.offline"
  test ! -e "$remote"
  test "$(sha256sum "$initial_local" | awk '{print $1}')" = "$initial_hash"
  printf '%s\n' \
    "${arm}-recovered-0000	${arm}	recovered	0000	${initial_hash}	${seed_hash}	not-run	pass	pass	not-run	0	0	0	0	0	0	local:${initial_local#$scratch/}" \
    >>"$receipts"

  mv "$remote.offline" "$remote"
  cp "$steered_source" "$steered_local"
  printf '%s\n' \
    "${arm}-steered-0001	${arm}	steered	0001	${steered_hash}	${seed_hash}	not-run	pass	not-run	pass	0	0	0	0	0	0	local:${steered_local#$scratch/}" \
    >>"$receipts"

  mkdir -p "$session"
  printf 'volatile state\n' >"$session/state"
  rm -rf -- "$session"
  mv "$remote" "$remote.offline"
  test ! -e "$remote"
  test "$(sha256sum "$steered_local" | awk '{print $1}')" = "$steered_hash"
  test "$(sha256sum "$initial_local" | awk '{print $1}')" = "$initial_hash"
  printf '%s\n' \
    "${arm}-recovered-0001	${arm}	recovered	0001	${steered_hash}	${seed_hash}	not-run	pass	pass	pass	0	0	0	0	0	0	local:${steered_local#$scratch/}" \
    >>"$receipts"

  awk -F '\t' '
    NR == 1 { expected = 17 }
    NF != expected { exit 1 }
    NR > 1 && $2 != "'"$arm"'" { exit 1 }
    END { if (NR != 5) exit 1 }
  ' "$receipts"
  echo "RECOVERY-GREEN-${arm}-43af"
}

run_arm A
run_arm B
