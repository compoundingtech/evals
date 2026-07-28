#!/usr/bin/env bash
set -euo pipefail

count_file="${CATALOG:?CATALOG must be set}/generation-count"
generation=1
if test -f "$count_file"; then
  generation=$(( $(cat "$count_file") + 1 ))
fi
printf '%s\n' "$generation" >"$count_file"
printf 'GENERATION_%s_OUT_c81a\n' "$generation"
printf 'GENERATION_%s_ERR_c81a\n' "$generation" >&2
sleep 100000 &
printf '%s\n' "$!" >"$CATALOG/generation-child-$generation"
wait
