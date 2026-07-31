#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"
source bin/st2-pin.sh

candidate="$ST2_BINARY_PATH"
if [ "${1:-}" = "--binary" ] && [ "$#" -eq 2 ]; then
  candidate="$2"
elif [ "$#" -ne 0 ]; then
  echo "usage: bin/check-st2-package-provenance.sh [--binary PATH]" >&2
  exit 2
fi

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

[[ "$ST2_SOURCE_FULL" =~ ^[0-9a-f]{40}$ ]] ||
  fail "st2 source identity is not a full Git object id: $ST2_SOURCE_FULL"
[[ "$ST2_SOURCE_SHORT" = "${ST2_SOURCE_FULL:0:${#ST2_SOURCE_SHORT}}" ]] ||
  fail "st2 short source identity is not a prefix of the full object id"

[ -f "$ST2_SOURCE_PATH/flake.lock" ] ||
  fail "pinned st2 source flake.lock is absent: $ST2_SOURCE_PATH/flake.lock"
actual_lock_sha256="$(sha256sum "$ST2_SOURCE_PATH/flake.lock" | awk '{ print $1 }')"
[ "$actual_lock_sha256" = "$ST2_FLAKE_LOCK_SHA256" ] ||
  fail "st2 flake.lock sha256 is $actual_lock_sha256, expected $ST2_FLAKE_LOCK_SHA256"

[ -e "$ST2_DERIVATION" ] || fail "pinned st2 derivation is absent: $ST2_DERIVATION"
[ -x "$ST2_BINARY_PATH" ] || fail "pinned packaged st2 binary is absent: $ST2_BINARY_PATH"

derivation_json="$(nix derivation show "$ST2_DERIVATION")"
jq -e \
  --arg drv "$(basename "$ST2_DERIVATION")" \
  --arg src "$ST2_SOURCE_PATH" \
  --arg out "$ST2_OUTPUT_PATH" \
  --arg rev "$ST2_SOURCE_SHORT" \
  '
    .derivations[$drv].env as $env |
    $env.src == $src and
    $env.out == $out and
    ($env.CLI_BUILD_STAMP | fromjson |
      .version == "0.1.0" and .type == "nix" and .dirty == false and .rev == $rev)
  ' <<<"$derivation_json" >/dev/null ||
  fail "pinned derivation does not bind the exact source, output, and clean build stamp"

path_info="$(nix path-info --json --json-format 1 "$ST2_OUTPUT_PATH")"
jq -e \
  --arg out "$ST2_OUTPUT_PATH" \
  --arg drv "$ST2_DERIVATION" \
  --arg nar "$ST2_OUTPUT_NAR_HASH" \
  --argjson size "$ST2_OUTPUT_NAR_SIZE" \
  '.[$out].deriver == $drv and .[$out].narHash == $nar and .[$out].narSize == $size' \
  <<<"$path_info" >/dev/null ||
  fail "pinned output does not have the exact derivation, NAR hash, and NAR size"

candidate_real="$(readlink -f "$candidate" 2>/dev/null || true)"
[ "$candidate_real" = "$ST2_BINARY_PATH" ] ||
  fail "candidate st2 is not the pinned packaged binary: ${candidate_real:-$candidate}"

actual_version="$("$candidate_real" --version)"
case "$actual_version" in
  "$ST2_VERSION_PREFIX"*) ;;
  *) fail "packaged st2 version is '$actual_version', expected prefix '$ST2_VERSION_PREFIX'" ;;
esac

actual_binary_sha256="$(sha256sum "$candidate_real" | awk '{ print $1 }')"
[ "$actual_binary_sha256" = "$ST2_BINARY_SHA256" ] ||
  fail "packaged st2 binary sha256 is $actual_binary_sha256, expected $ST2_BINARY_SHA256"

printf 'PASS: packaged st2 provenance %s -> %s (%s; %s)\n' \
  "$ST2_SOURCE_FULL" "$ST2_OUTPUT_PATH" "$ST2_OUTPUT_NAR_HASH" "$actual_binary_sha256"
