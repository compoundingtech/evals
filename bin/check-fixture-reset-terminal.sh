#!/usr/bin/env bash
# Prove deterministic fixture-reset output and cleanup are identical with and without a terminal.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

command -v script >/dev/null || {
  echo "FAIL: fixture-reset terminal regression requires util-linux script" >&2
  exit 1
}

scratch="$(mktemp -d)"
cleanup() {
  rm -rf -- "$scratch"
}
trap cleanup EXIT

plain="$scratch/plain.out"
terminal="$scratch/terminal.out"

bin/check-fixture-reset.sh >"$plain"
CHECK_FIXTURE_RESET="$repo_root/bin/check-fixture-reset.sh" \
  script -qefc 'exec "$CHECK_FIXTURE_RESET"' /dev/null </dev/null |
  tr -d '\r' >"$terminal"

if ! cmp -s "$plain" "$terminal"; then
  diff -u "$plain" "$terminal" >&2 || true
  echo "FAIL: fixture-reset gate differs with a terminal attached" >&2
  exit 1
fi

sed -n '1,240p' "$plain"
echo "PASS: fixture-reset gate and owned-mktemp cleanup are terminal-independent"
