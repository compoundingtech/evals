#!/usr/bin/env bash
# Emit the stable, mechanically derived overnight inventory as TSV.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

include_header=1
if [ "${1:-}" = "--no-header" ]; then
  include_header=0
elif [ "$#" -ne 0 ]; then
  echo "usage: bin/corpus-inventory.sh [--no-header]" >&2
  exit 2
fi

agent_inventory="$(mktemp)"
cleanup() {
  rm -f -- "$agent_inventory"
}
trap cleanup EXIT
bin/model-agent-inventory.sh --no-header > "$agent_inventory"

if [ "$include_header" -eq 1 ]; then
  printf 'cell\tharness\tmodels\teffort\tmodel_agents\tcost_band\ttimeout\theld_out_judges\n'
fi

mapfile -t cells < <(find cells -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | LC_ALL=C sort)
[ "${#cells[@]}" -gt 0 ] || {
  echo "FAIL: no cell KDLs found" >&2
  exit 1
}

for cell in "${cells[@]}"; do
  cell_dir="cells/$cell"
  kdl="$cell_dir/$cell.kdl"
  [ -f "$kdl" ] || {
    echo "FAIL: $cell_dir must contain the canonical $cell.kdl" >&2
    exit 1
  }
  extra_kdl="$(find "$cell_dir" -maxdepth 1 -type f -name '*.kdl' ! -name "$cell.kdl" -print -quit)"
  [ -z "$extra_kdl" ] || {
    echo "FAIL: $cell_dir contains a second root KDL: $extra_kdl" >&2
    exit 1
  }

  mapfile -t timeouts < <(
    sed -n 's/^[[:space:]]*max-timeout[[:space:]]*"\([^"]*\)".*/\1/p' "$kdl"
  )
  [ "${#timeouts[@]}" -eq 1 ] || {
    echo "FAIL: $kdl must declare exactly one max-timeout" >&2
    exit 1
  }
  timeout="${timeouts[0]}"

  claude="$(awk -F '\t' -v cell="$cell" '$1 == cell && $3 == "Claude" { count += 1 } END { print count + 0 }' "$agent_inventory")"
  codex="$(awk -F '\t' -v cell="$cell" '$1 == cell && $3 == "Codex" { count += 1 } END { print count + 0 }' "$agent_inventory")"

  agents=$((claude + codex))
  if [ "$claude" -gt 0 ] && [ "$codex" -gt 0 ]; then
    harness="mixed"
    models="claude-sonnet-5+gpt-5.6-sol"
  elif [ "$claude" -gt 0 ]; then
    harness="Claude"
    models="claude-sonnet-5"
  elif [ "$codex" -gt 0 ]; then
    harness="Codex"
    models="gpt-5.6-sol"
  else
    harness="model-free"
    models="-"
  fi

  if [ "$agents" -eq 0 ]; then
    effort="-"
    cost="none"
  elif [ "$agents" -eq 1 ]; then
    effort="medium"
    cost="low"
  elif [ "$agents" -eq 2 ]; then
    effort="medium"
    cost="medium"
  else
    effort="medium"
    cost="high"
  fi

  judges="$(rg -c '^[[:space:]]*judge[[:space:]]+"' "$kdl" || true)"
  judges="${judges:-0}"
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$cell" "$harness" "$models" "$effort" "$agents" "$cost" "$timeout" "$judges"
done
