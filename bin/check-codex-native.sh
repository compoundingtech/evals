#!/usr/bin/env bash
# Verify that selected Codex evals are native-only and that every declared workspace receives AGENTS.md.
set -euo pipefail

if [ "$#" -eq 0 ]; then
  set -- \
    cells/license-mit-codex \
    cells/signal-rename-codex \
    cells/ghost-bug-codex \
    cells/poisoned-pr-codex \
    cells/fork-in-the-road-codex
fi

failed=0

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  failed=1
  cell_failed=1
}

for cell in "$@"; do
  cell_failed=0
  name="${cell%/}"
  name="${name##*/}"
  kdl="$cell/$name.kdl"

  if [ ! -f "$kdl" ]; then
    fail "$cell has no canonical $name.kdl"
    continue
  fi

  if rg -n -i \
    'smalltalk|convoy|\$CATALOG/smalltalk|exec[[:space:]]+"[^"]*\.ding"|st2[[:space:]]+ding|exec[[:space:]]+claude|permission-mode' \
    "$cell" --glob '!**/_git/**' --glob '!README.md'; then
    fail "$cell contains a legacy bus/harness declaration"
  fi

  agent_count="$(rg -c '^[[:space:]]*agent[[:space:]]+"' "$kdl" || true)"
  ding_count="$(rg -c '^[[:space:]]*ding[[:space:]]*$' "$kdl" || true)"
  codex_count="$(rg -c '^[[:space:]]*command[[:space:]]+#"exec codex ' "$kdl" || true)"

  if [ "$agent_count" -eq 0 ]; then
    fail "$kdl declares no agents"
  fi
  if [ "$ding_count" -ne "$agent_count" ]; then
    fail "$kdl has $agent_count agents but $ding_count native ding declarations"
  fi
  if [ "$codex_count" -ne "$agent_count" ]; then
    fail "$kdl has $agent_count agents but $codex_count Codex commands"
  fi

  scratch=""
  fixture="$cell/fixture"
  if [ -x "$fixture/materialize.sh" ]; then
    scratch="$(mktemp -d)"
    cp -R "$fixture"/. "$scratch"/
    CATALOG="$scratch" bash "$scratch/materialize.sh" >/dev/null
    fixture="$scratch"
  fi

  while IFS= read -r workspace; do
    relative="${workspace#./}"
    target="$fixture/$relative/AGENTS.md"
    if [ "$relative" = "" ]; then
      target="$fixture/AGENTS.md"
    fi
    if [ ! -s "$target" ]; then
      fail "$cell workspace '$workspace' does not receive a non-empty AGENTS.md"
    fi
  done < <(sed -n 's/^[[:space:]]*workspace[[:space:]]*"\([^"]*\)".*/\1/p' "$kdl")

  if [ -n "$scratch" ]; then
    rm -rf "$scratch"
  fi

  if [ "$cell_failed" -eq 0 ]; then
    printf 'PASS: %s is Codex-only, native-ding, and explicitly personae’d\n' "$cell"
  fi
done

exit "$failed"
