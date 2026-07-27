#!/usr/bin/env bash
# Compatibility entrypoint: fixture reset is one corpus-wide contract.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [ "$#" -gt 0 ]; then
  printf 'NOTE: per-cell arguments are ignored; every maintained fixture is reset\n'
fi
exec "$repo_root/bin/check-fixture-reset.sh"
