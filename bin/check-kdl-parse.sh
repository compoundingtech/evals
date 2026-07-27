#!/usr/bin/env bash
# Parse every active KDL with the exact kdl-rs version pinned by st2 25d8371. Starts no eval.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

mapfile -t kdls < <(
  find cells -type f -name '*.kdl' -not -path '*/_git/*' | LC_ALL=C sort
)
[ "${#kdls[@]}" -gt 0 ] || {
  echo "FAIL: no KDL files found" >&2
  exit 1
}

target_dir="$repo_root/.build/kdl-check"
CARGO_TARGET_DIR="$target_dir" cargo run \
  --quiet \
  --locked \
  --manifest-path tools/kdl-check/Cargo.toml \
  -- "${kdls[@]}"

printf 'PASS: %s KDL files parse with st2-pinned kdl-rs 6.7.1; no eval was started\n' "${#kdls[@]}"
