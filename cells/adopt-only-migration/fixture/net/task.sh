#!/usr/bin/env bash
set -euo pipefail

label="${1:?label is required}"
count_file="${CATALOG:?CATALOG must be set}/$label-count"
generation=1
if test -f "$count_file"; then
  generation=$(( $(cat "$count_file") + 1 ))
fi
printf '%s\n' "$generation" >"$count_file"
printf '%s-GENERATION-%s-a091\n' "$label" "$generation"
sleep 100000
