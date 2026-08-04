#!/usr/bin/env bash
set -euo pipefail

marker="${1:?marker path required}"
printf 'run\n' >>"$marker"
printf 'LIVE-RECOVERY-READY\n'
while IFS= read -r line; do
  printf 'LIVE-RECOVERY-ACK:%s\n' "$line"
done
