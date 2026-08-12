#!/usr/bin/env bash
# SIGNAL JUDGE — never gates. Records the descriptive per-run metrics the delegation-parity design asks for and
# appends one row to the ignored working-tree sink `.eval-runs/observations/<cell>.tsv`, because `st2 eval`
# discards judge stdout and keeps no wall-clock, message-count, or cost fields of its own.
#
#   observe.sh <arm>
#
# Task latency is measured on the bus, not from the runner: it is the interval between the kickoff receipt in
# the coordinator's mailbox and the coordinator's confirmation in the requester's mailbox. That is the only
# arm-comparable timing available, because a single-seat compact eval never signals completion to the runner
# and therefore always consumes its whole `max-timeout`.
set -uo pipefail
ROOT="${CATALOG:-$PWD}"
SPEC="${SPEC_DIR:-$PWD}"
BUS="${ST_ROOT:-$ROOT}"
ARM="${1:-unknown}"
CELL="$(basename "$SPEC")"
SINK_DIR="$SPEC/../../.eval-runs/observations"

ts_of() { # message filenames are <unix-ms>-<rand6>.md
  basename "$1" | sed -n 's/^\([0-9][0-9]*\)-.*$/\1/p'
}

first_ts() { # first_ts <mailbox-dir> <sender-suffix-regex>
  local dir="$1" from="$2" file ts best=""
  while IFS= read -r file; do
    ts="$(ts_of "$file")"
    [ -n "$ts" ] || continue
    if [ -z "$best" ] || [ "$ts" -lt "$best" ]; then best="$ts"; fi
  done < <(grep -lRE "^from:[[:space:]]*$from([[:space:]]|\$)" "$dir/inbox" "$dir/archive" 2>/dev/null)
  printf '%s\n' "$best"
}

last_ts() { # last_ts <mailbox-dir> <sender-suffix-regex>
  local dir="$1" from="$2" file ts best=""
  while IFS= read -r file; do
    ts="$(ts_of "$file")"
    [ -n "$ts" ] || continue
    if [ -z "$best" ] || [ "$ts" -gt "$best" ]; then best="$ts"; fi
  done < <(grep -lRE "^from:[[:space:]]*$from([[:space:]]|\$)" "$dir/inbox" "$dir/archive" 2>/dev/null)
  printf '%s\n' "$best"
}

sup_dir="$(ls -d "$BUS"/*.sup 2>/dev/null | head -1)"
req_dir="$(ls -d "$BUS"/*requester "$BUS"/requester 2>/dev/null | head -1)"

kickoff_ms="$([ -n "$sup_dir" ] && first_ts "$sup_dir" "([a-z0-9][a-z0-9._-]*\.)?requester" || true)"
confirm_ms="$([ -n "$req_dir" ] && last_ts "$req_dir" "([a-z0-9][a-z0-9._-]*\.)?[a-z0-9._-]*sup" || true)"
latency_ms="-"
if [ -n "${kickoff_ms:-}" ] && [ -n "${confirm_ms:-}" ]; then
  latency_ms=$((confirm_ms - kickoff_ms))
fi

bus_messages="$(find "$BUS" -mindepth 3 -maxdepth 3 -type f -name '*.md' \
  \( -path '*/inbox/*' -o -path '*/archive/*' \) 2>/dev/null | wc -l | tr -d ' ')"
seats="$(find "$BUS" -maxdepth 2 -type d -name inbox 2>/dev/null | wc -l | tr -d ' ')"
# One label per attribution line: a delegation-log line carries trailing slice/tool fields.
delegates="$(grep -hEo '^[[:space:]]*delegate:[[:space:]]*[^[:space:]]+' "$ROOT"/findings/*.md 2>/dev/null |
  sed -e 's/^[[:space:]]*delegate:[[:space:]]*//' |
  LC_ALL=C sort -u | paste -sd, -)"
deliverables="$(ls "$ROOT/findings" 2>/dev/null | LC_ALL=C sort | paste -sd, -)"

row="$(printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s' \
  "$CELL" "$ARM" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  "${kickoff_ms:--}" "${confirm_ms:--}" "$latency_ms" \
  "$bus_messages" "$seats" "${delegates:--}" "${deliverables:--}")"

mkdir -p "$SINK_DIR" 2>/dev/null || true
sink="$SINK_DIR/$CELL.tsv"
if [ ! -f "$sink" ]; then
  printf 'cell\tarm\trecorded_at_utc\tkickoff_ms\tconfirm_ms\tlatency_ms\tbus_messages\tbus_seats\tdelegate_labels\tdeliverables\n' \
    > "$sink" 2>/dev/null || true
fi
printf '%s\n' "$row" >> "$sink" 2>/dev/null || true

echo "OBSERVED $row"
echo "  sink: $sink"
exit 0
