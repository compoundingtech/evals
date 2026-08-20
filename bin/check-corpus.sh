#!/usr/bin/env bash
# Complete free preflight for the current overnight corpus. Never starts a model seat.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

expected_source="6e06b55"
expected_binary_sha256="b5a2a408830039e35ebfbfd4ab29ba66c629b810c8e7efa4f1d061faba3d405f"
expected_version_regex='^st2 0\.1\.0 — running from local source \(6e06b55, .+ ago\)$'
st2_path="$(command -v st2)"
actual_version="$(st2 --version)"
[[ "$actual_version" =~ $expected_version_regex ]] || {
  echo "FAIL: expected st2 0.1.0 from pinned source $expected_source, found $actual_version" >&2
  exit 1
}
actual_binary_sha256="$(sha256sum "$st2_path" | awk '{ print $1 }')"
[ "$actual_binary_sha256" = "$expected_binary_sha256" ] || {
  echo "FAIL: expected st2 binary sha256 $expected_binary_sha256, found $actual_binary_sha256 at $st2_path" >&2
  exit 1
}
echo "PASS: pinned runner source $expected_source ($actual_version; sha256 $actual_binary_sha256)"

mapfile -d '' shell_files < <(
  find bin cells -type f -name '*.sh' -not -path '*/_git/*' -print0 | sort -z
)
bash -n "${shell_files[@]}"
echo "PASS: ${#shell_files[@]} shell files parse"

bin/check-preflight-safety.sh
bin/check-model-policy.sh
bin/check-model-policy-mutations.sh
bin/check-run-history.sh
bin/check-retired-surfaces.sh
bin/model-seat-inventory.sh >/dev/null
bin/check-event-first.sh
bin/check-kdl-parse.sh
bin/check-st2-semantic.sh
bin/check-fixture-reset-terminal.sh
bin/check-harness-contract.sh
bin/check-vrs-scope-drift.sh
bin/check-vrs-variations.sh
bin/check-weird-git-setup.sh
bin/check-preflight-closed-set-mutations.sh
bin/check-overnight-policy.sh
bin/check-no-pii.sh
bin/check-no-pii-history.sh
bin/generate-catalog.sh --check
git diff --check HEAD

echo "PASS: complete model-free corpus preflight"
