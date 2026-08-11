#!/usr/bin/env bash
# Emit every maintained model seat directly from the root folder-eval declarations.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

include_header=1
if [ "${1:-}" = "--no-header" ]; then
  include_header=0
elif [ "$#" -ne 0 ]; then
  echo "usage: bin/model-seat-inventory.sh [--no-header]" >&2
  exit 2
fi

inventory="$(mktemp)"
cleanup() {
  rm -f -- "$inventory"
}
trap cleanup EXIT

failed=0
while IFS= read -r cell; do
  kdl="cells/$cell/$cell.kdl"
  [ -f "$kdl" ] || {
    echo "FAIL: $cell has no canonical root declaration $kdl" >&2
    failed=1
    continue
  }

  if ! awk -v cell="$cell" '
    function direct(line) {
      return index(line, child_indent) == 1
    }
    function finish_agent() {
      if (harness == "") {
        return
      }
      if (workspace == "") {
        printf "FAIL: %s agent %s has a model command but no direct workspace\n", cell, agent > "/dev/stderr"
        bad = 1
      }
      if (st_agent == "") {
        printf "FAIL: %s agent %s has a model command but no direct ST_AGENT\n", cell, agent > "/dev/stderr"
        bad = 1
      }
      native_delivery = (harness == "Codex" && delivery == "app-server" && ding == 0) || (delivery == "" && ding == 1)
      if (!native_delivery) {
        printf "FAIL: %s agent %s has invalid native delivery (harness=%s delivery=%s ding=%d)\n", cell, agent, harness, delivery, ding > "/dev/stderr"
        bad = 1
      }
      if (workspace != "" && st_agent != "" && native_delivery) {
        printf "%s\t%s\t%s\t%s\t%s\t%d\n", cell, agent, harness, workspace, st_agent, command_line
      }
    }
    /^[[:space:]]*agent[[:space:]]+"/ {
      if (in_agent) {
        finish_agent()
      }
      in_agent = 1
      indent = $0
      sub(/[^[:space:]].*/, "", indent)
      child_indent = indent "  "
      agent = $0
      sub(/^[[:space:]]*agent[[:space:]]+"/, "", agent)
      sub(/".*/, "", agent)
      workspace = ""
      st_agent = ""
      harness = ""
      command_line = 0
      ding = 0
      delivery = ""
      next
    }
    in_agent {
      closing = indent "}"
      trimmed = $0
      sub(/[[:space:]]*\/\/.*/, "", trimmed)
      sub(/[[:space:]]+$/, "", trimmed)
      if (trimmed == closing) {
        finish_agent()
        in_agent = 0
        next
      }
      if (!direct($0)) {
        next
      }
      if ($0 ~ /^[[:space:]]*workspace[[:space:]]+"/) {
        workspace = $0
        sub(/^[[:space:]]*workspace[[:space:]]+"/, "", workspace)
        sub(/".*/, "", workspace)
      }
      if ($0 ~ /^[[:space:]]*env[[:space:]]*\{/ && $0 ~ /ST_AGENT[[:space:]]+"/) {
        st_agent = $0
        sub(/.*ST_AGENT[[:space:]]+"/, "", st_agent)
        sub(/".*/, "", st_agent)
      }
      if ($0 ~ /^[[:space:]]*(command|argv)[[:space:]]+/) {
        if ($0 ~ /exec claude[[:space:]]/) {
          harness = "Claude"
          command_line = NR
        } else if ($0 ~ /(exec codex[[:space:]]|argv[[:space:]]+"codex")/) {
          harness = "Codex"
          command_line = NR
        }
      }
      if ($0 ~ /^[[:space:]]*deliver[[:space:]]+"/) {
        delivery = $0
        sub(/^[[:space:]]*deliver[[:space:]]+"/, "", delivery)
        sub(/".*/, "", delivery)
      }
      if (trimmed == child_indent "ding") {
        ding += 1
      }
    }
    END {
      if (in_agent) {
        finish_agent()
      }
      exit bad
    }
  ' "$kdl" >> "$inventory"; then
    failed=1
  fi
done < <(find cells -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | LC_ALL=C sort)

launches="$(
  rg -n --no-heading '^[[:space:]]*(command[[:space:]]+.*exec |argv[[:space:]]+")(claude|codex)' \
    cells/*/*.kdl | wc -l | tr -d ' '
)"
rows="$(wc -l < "$inventory" | tr -d ' ')"
if [ "$rows" -ne "$launches" ]; then
  echo "FAIL: model-seat inventory found $rows structured seats but $launches root-KDL launch lines" >&2
  failed=1
fi

[ "$failed" -eq 0 ] || exit 1
if [ "$include_header" -eq 1 ]; then
  printf 'cell\tagent\tharness\tworkspace\tst_agent\tcommand_line\n'
fi
cat "$inventory"
