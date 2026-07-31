#!/usr/bin/env bash
# Prove the append-only helper accepts an append and rejects a baseline-row rewrite.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
scratch="$(mktemp -d)"
trap 'rm -rf -- "$scratch"' EXIT

git -C "$scratch" init -q --initial-branch=main
mkdir -p "$scratch/evidence"
printf 'header\nbaseline-row\n' >"$scratch/evidence/attempts.tsv"
git -C "$scratch" add evidence/attempts.tsv
GIT_AUTHOR_DATE="2000-01-01T00:00:00Z" \
GIT_COMMITTER_DATE="2000-01-01T00:00:00Z" \
  git -C "$scratch" \
    -c core.hooksPath=/dev/null \
    -c user.name=eval-fixture \
    -c user.email=eval-fixture@local \
    commit -q -m "fixture: append-only baseline"
baseline="$(git -C "$scratch" rev-parse HEAD)"

printf 'appended-row\n' >>"$scratch/evidence/attempts.tsv"
"$repo_root/bin/check-append-only-file.sh" \
  --repo-root "$scratch" --baseline "$baseline" --path evidence/attempts.tsv >/dev/null

printf 'header\nrewritten-row\nappended-row\n' >"$scratch/evidence/attempts.tsv"
if "$repo_root/bin/check-append-only-file.sh" \
  --repo-root "$scratch" --baseline "$baseline" --path evidence/attempts.tsv >/dev/null 2>&1; then
  echo "FAIL: append-only helper accepted a rewritten baseline row" >&2
  exit 1
fi

echo "PASS: append-only mutation accepts appended bytes and rejects a baseline-row rewrite"
