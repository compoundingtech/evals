#!/usr/bin/env bash
set -euo pipefail

mode="${1:?grade mode required}"
case "$mode" in
  intent)
    bash ./judges/grade-case.sh implementation structural
    bash ./judges/grade-case.sh implementation semantic
    ;;
  bundle|inbox|boundary)
    bash ./judges/grade-case.sh implementation "$mode"
    ;;
  *)
    echo "unknown grade mode: $mode" >&2
    exit 2
    ;;
esac
