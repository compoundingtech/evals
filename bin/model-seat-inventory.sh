#!/usr/bin/env bash
# Emit every maintained model seat from compact eval declarations and canonical templates.
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

  if ! awk -v cell="$cell" -v source_path="$kdl" '
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
      if (ding != 1) {
        printf "FAIL: %s agent %s has a model command but %d direct bare ding declarations\n", cell, agent, ding > "/dev/stderr"
        bad = 1
      }
      if (workspace != "" && st_agent != "" && ding == 1) {
        printf "%s\t%s\t%s\t%s\t%s\tcompact\t%s\t%d\n", cell, agent, harness, workspace, st_agent, source_path, command_line
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
      if ($0 ~ /^[[:space:]]*command[[:space:]]+/) {
        if ($0 ~ /exec claude[[:space:]]/) {
          harness = "Claude"
          command_line = NR
        } else if ($0 ~ /exec codex[[:space:]]/) {
          harness = "Codex"
          command_line = NR
        } else if ($0 ~ /exec axe agent launch[[:space:]]/ &&
                   $0 ~ /--harness[[:space:]]+claude([[:space:]]|$)/) {
          harness = "Claude"
          command_line = NR
        } else if ($0 ~ /exec axe agent launch[[:space:]]/ &&
                   $0 ~ /--harness[[:space:]]+codex([[:space:]]|$)/) {
          harness = "Codex"
          command_line = NR
        }
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

while IFS= read -r template; do
  cell="${template#cells/}"
  cell="${cell%%/*}"
  agent="$(sed -n 's/^[[:space:]]*agent[[:space:]]*"\([^"]*\)".*/\1/p' "$template")"
  workspace="$(sed -n 's/^[[:space:]]*workspace[[:space:]]*"\([^"]*\)".*/\1/p' "$template")"
  st_agent="$(sed -n 's/^[[:space:]]*ST_AGENT[[:space:]]*"\([^"]*\)".*/\1/p' "$template")"
  command_line="$(rg -n '^[[:space:]]*argv[[:space:]].*"agent"[[:space:]]+"launch"' "$template" | cut -d: -f1)"
  command_text="$(sed -n "${command_line}p" "$template")"
  ding_count="$(rg -c '^[[:space:]]*ding[[:space:]]*$' "$template" || true)"
  harness=""
  if grep -Fq '"--harness" "claude"' <<< "$command_text"; then
    harness="Claude"
  elif grep -Fq '"--harness" "codex"' <<< "$command_text"; then
    harness="Codex"
  fi
  if [ -z "$agent" ] || [ -z "$workspace" ] || [ -z "$st_agent" ] ||
    [ -z "$command_line" ] || [ -z "$harness" ] || [ "$ding_count" -ne 1 ]; then
    echo "FAIL: canonical model-seat template is incomplete: $template" >&2
    failed=1
    continue
  fi
  printf '%s\t%s\t%s\t%s\t%s\tcanonical-template\t%s\t%s\n' \
    "$cell" "$agent" "$harness" "$workspace" "$st_agent" "$template" "$command_line" \
    >> "$inventory"
done < <(find cells -type f -name 'agent.kdl.template' | LC_ALL=C sort)

launches="$(
  {
    rg -n --no-heading '^[[:space:]]*command[[:space:]]+.*exec ((claude|codex)[[:space:]]|axe agent launch[[:space:]])' \
      cells/*/*.kdl || true
    rg -n --no-heading '^[[:space:]]*argv[[:space:]].*"agent"[[:space:]]+"launch"' \
      cells -g 'agent.kdl.template' || true
  } | wc -l | tr -d ' '
)"
rows="$(wc -l < "$inventory" | tr -d ' ')"
if [ "$rows" -ne "$launches" ]; then
  echo "FAIL: model-seat inventory found $rows structured seats but $launches root-KDL launch lines" >&2
  failed=1
fi

[ "$failed" -eq 0 ] || exit 1
if [ "$include_header" -eq 1 ]; then
  printf 'cell\tagent\tharness\tworkspace\tst_agent\tsource_kind\tsource_path\tsource_line\n'
fi
cat "$inventory"
