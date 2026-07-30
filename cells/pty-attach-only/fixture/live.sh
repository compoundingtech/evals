#!/usr/bin/env bash
set -euo pipefail

marker="${1:?marker path required}"
printf 'run\n' >>"$marker"
printf 'ATTACH-ONLY-LIVE-READY\n'
IFS= read -r line
printf 'LIVE-ACK:%s\n' "$line"
exit 37
