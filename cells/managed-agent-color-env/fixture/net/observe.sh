#!/usr/bin/env bash
set -euo pipefail

name="${1:?name required}"
observed="$CATALOG/observed"
mkdir -p "$observed"
count_file="$observed/$name.count"
count=0
test ! -f "$count_file" || count="$(cat "$count_file")"
count=$((count + 1))
printf '%s\n' "$count" > "$count_file"

if test "${NO_COLOR+x}" = x; then
  no_color="$NO_COLOR"
else
  no_color='<unset>'
fi
{
  printf 'NO_COLOR=%s\n' "$no_color"
  printf 'TERM=%s\n' "${TERM-<unset>}"
} > "$observed/$name.$count"

exec sleep 300
