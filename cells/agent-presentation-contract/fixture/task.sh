#!/usr/bin/env bash
set -euo pipefail

label="${1:?task label required}"
count_file="${CATALOG:?CATALOG must be set}/$label-count"
count=0
test ! -f "$count_file" || count="$(cat "$count_file")"
count=$((count + 1))
printf '%s\n' "$count" >"$count_file"
printf '%s-GENERATION-%s-b128\n' "$label" "$count"
exec sleep 300
