#!/usr/bin/env bash
set -euo pipefail

mode="${1:?grade mode required}"
root="${CATALOG:?CATALOG required}/out"

grade_case() {
  bash ./inspect-case.sh "$1" "$root/$1"
}

case "$mode" in
  success)
    grade_case success
    ;;
  recovery)
    grade_case crash-pre-retire
    grade_case crash-post-retire
    grade_case crash-post-publish
    ;;
  cancel-crash)
    grade_case cancel
    grade_case process-crash-before-intent
    ;;
  concurrency)
    grade_case concurrent-resume
    ;;
  *)
    echo "unknown grade mode: $mode" >&2
    exit 2
    ;;
esac
