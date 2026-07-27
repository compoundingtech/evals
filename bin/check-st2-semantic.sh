#!/usr/bin/env bash
# Parse every folder eval through st2's own semantic loader and validate nested fleet declarations.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

cells=0
while IFS= read -r cell; do
  st2 ls "cells/$cell" >/dev/null
  ((cells += 1))
done < <(find cells -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | LC_ALL=C sort)

catalog_hosts="$(mktemp)"
cleanup() {
  rm -f -- "$catalog_hosts"
}
trap cleanup EXIT

while IFS= read -r declaration; do
  catalog="${declaration%%/fixture/net/*}/fixture/net"
  host="$(
    awk '
      /^[[:space:]]*host[[:space:]]*"/ {
        value = $0
        sub(/^[[:space:]]*host[[:space:]]*"/, "", value)
        sub(/".*/, "", value)
        print value
        exit
      }
    ' "$declaration"
  )"
  [ -n "$host" ] || {
    echo "FAIL: nested fleet declaration has no explicit host: $declaration" >&2
    exit 1
  }
  printf '%s\t%s\n' "$catalog" "$host"
done < <(
  find cells -path '*/fixture/net/*' -type f -name 'agent.kdl' | LC_ALL=C sort
) | LC_ALL=C sort -u > "$catalog_hosts"

catalogs=0
while IFS=$'\t' read -r catalog host; do
  st2 validate --catalog "$catalog" --host "$host" --strict >/dev/null
  ((catalogs += 1))
done < "$catalog_hosts"

printf 'PASS: st2 semantically loads %d maintained folder evals and strictly validates %d nested fleet catalogs\n' \
  "$cells" "$catalogs"
