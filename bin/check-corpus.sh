#!/usr/bin/env bash
# Complete free preflight for the current overnight corpus. Never starts a model seat.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

expected_source="8280069"
expected_source_full="8280069d6b8f17a3aab2305dc1dfcd3365946ef3"
expected_binary_sha256="f63a4d74762dc12a1854e118f5d2b0d89d3b5497b1de473fb277bd6046c4509e"
expected_version_regex='^st2 0\.1\.0 — running from local source \(8280069, .+ ago\)$'
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
LC_ALL=C grep -aFq "$expected_source_full" "$st2_path" || {
  echo "FAIL: st2 binary at $st2_path does not embed full pinned source $expected_source_full" >&2
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
bin/check-retired-surfaces.sh
bin/model-seat-inventory.sh >/dev/null
bin/check-event-first.sh
bin/check-kdl-parse.sh
bin/check-st2-semantic.sh
bin/check-fixture-reset.sh
bin/check-harness-contract.sh
bin/check-overnight-policy.sh
bin/check-no-pii.sh
bin/generate-catalog.sh --check
git diff --check HEAD

echo "PASS: complete model-free corpus preflight"
