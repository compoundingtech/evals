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
hostile="$scratch/hostile.out"
hostile_hooks="$scratch/hostile-hooks"
hostile_config="$scratch/hostile.gitconfig"

bin/check-fixture-reset.sh >"$plain"
CHECK_FIXTURE_RESET="$repo_root/bin/check-fixture-reset.sh" \
  script -qefc 'exec "$CHECK_FIXTURE_RESET"' /dev/null </dev/null |
  tr -d '\r' >"$terminal"

mkdir -p "$hostile_hooks"
printf '%s\n' '#!/bin/sh' 'echo ambient-hook-ran >&2' 'exit 97' \
  >"$hostile_hooks/commit-msg"
chmod +x "$hostile_hooks/commit-msg"
git config -f "$hostile_config" core.hooksPath "$hostile_hooks"
git config -f "$hostile_config" user.name ambient-user
git config -f "$hostile_config" user.email ambient@example.invalid
GIT_CONFIG_GLOBAL="$hostile_config" GIT_CONFIG_NOSYSTEM=0 \
  bin/check-fixture-reset.sh >"$hostile"

if ! cmp -s "$plain" "$terminal"; then
  diff -u "$plain" "$terminal" >&2 || true
  echo "FAIL: fixture-reset gate differs with a terminal attached" >&2
  exit 1
fi
if ! cmp -s "$plain" "$hostile"; then
  diff -u "$plain" "$hostile" >&2 || true
  echo "FAIL: fixture reset depends on ambient Git config or hooks" >&2
  exit 1
fi

sed -n '1,240p' "$plain"
echo "PASS: fixture-reset gate is terminal-independent and ignores hostile ambient Git config/hooks"
