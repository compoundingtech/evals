#!/usr/bin/env bash
# Prove that a working-tree file preserves an immutable baseline blob as an exact prefix.
set -euo pipefail

repo_root=""
baseline=""
path=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --repo-root) repo_root="${2:-}"; shift 2 ;;
    --baseline) baseline="${2:-}"; shift 2 ;;
    --path) path="${2:-}"; shift 2 ;;
    *) echo "usage: $0 --repo-root DIR --baseline REF --path RELATIVE_PATH" >&2; exit 2 ;;
  esac
done
[ -n "$repo_root" ] && [ -n "$baseline" ] && [ -n "$path" ] ||
  { echo "usage: $0 --repo-root DIR --baseline REF --path RELATIVE_PATH" >&2; exit 2; }
[[ "$path" != /* && "$path" != *..* ]] ||
  { echo "FAIL: append-only path must be repository-relative" >&2; exit 1; }

baseline_commit="$(git -C "$repo_root" rev-parse --verify "$baseline^{commit}")" ||
  { echo "FAIL: append-only baseline is not an immutable commit: $baseline" >&2; exit 1; }
git -C "$repo_root" cat-file -e "$baseline_commit:$path" 2>/dev/null ||
  { echo "FAIL: baseline $baseline_commit has no $path to compare" >&2; exit 1; }
[ -f "$repo_root/$path" ] || { echo "FAIL: working file is missing: $path" >&2; exit 1; }

prior="$(mktemp)"
trap 'rm -f -- "$prior"' EXIT
git -C "$repo_root" show "$baseline_commit:$path" >"$prior"
prior_size="$(wc -c <"$prior")"
current_size="$(wc -c <"$repo_root/$path")"
[ "$current_size" -ge "$prior_size" ] &&
  cmp -n "$prior_size" "$prior" "$repo_root/$path" || {
    echo "FAIL: $path rewrites or removes baseline $baseline_commit; only append bytes" >&2
    exit 1
  }
printf 'PASS: %s preserves baseline %s as an exact prefix\n' "$path" "$baseline_commit"
