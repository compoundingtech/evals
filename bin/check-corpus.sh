#!/usr/bin/env bash
# Complete free preflight for the current overnight corpus. Never starts a model seat.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

expected_source="acb0016"
expected_source_full="acb00164d8e1d0b08e70c8cc7fb932aee214f555"
expected_archive_sha256="c09a743c5a757998edcb3ff2963b80e459a9050d8c452d5eb3b241d34806ac86"
expected_binary_sha256="bd933332784b1d87ba3d539c5570e4e3fd0572504ee2ec1ee52acbb5e8cdbbf4"
expected_version_regex='^st2 0\.1\.0\+acb0016 — committed .+ ago$'
[[ "$expected_source_full" == "$expected_source"* ]] || {
  echo "FAIL: full pinned source $expected_source_full does not begin with short source $expected_source" >&2
  exit 1
}
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
echo "PASS: pinned runner source $expected_source_full (archive sha256 $expected_archive_sha256; $actual_version; binary sha256 $actual_binary_sha256)"

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
