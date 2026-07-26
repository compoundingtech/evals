#!/usr/bin/env bash
# Verify that selected Claude evals use current native ding and deliver explicit Claude personas.
set -euo pipefail

if [ "$#" -eq 0 ]; then
  set -- \
    cells/ding-reply \
    cells/signal-rename
fi

failed=0
scratch_roots=()

cleanup() {
  local scratch
  for scratch in "${scratch_roots[@]}"; do
    if [ -n "$scratch" ] && [ -d "$scratch" ]; then
      rm -rf -- "$scratch"
    fi
  done
}
trap cleanup EXIT

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
    'smalltalk|convoy|\$CATALOG/smalltalk|exec[[:space:]]+"[^"]*\.ding"|st2[[:space:]]+ding|exec[[:space:]]+codex' \
    "$cell" --glob '!**/_git/**' --glob '!README.md'; then
    fail "$cell contains a legacy bus/harness declaration"
  fi

  agent_count="$(rg -c '^[[:space:]]*agent[[:space:]]+"' "$kdl" || true)"
  ding_count="$(rg -c '^[[:space:]]*ding[[:space:]]*$' "$kdl" || true)"
  claude_count="$(rg -c '^[[:space:]]*command[[:space:]]+#"exec claude ' "$kdl" || true)"

  if [ "$agent_count" -eq 0 ]; then
    fail "$kdl declares no agents"
  fi
  if [ "$ding_count" -ne "$agent_count" ]; then
    fail "$kdl has $agent_count agents but $ding_count native ding declarations"
  fi
  if [ "$claude_count" -ne "$agent_count" ]; then
    fail "$kdl has $agent_count agents but $claude_count Claude commands"
  fi

  scratch=""
  fixture="$cell/fixture"
  if [ -x "$fixture/materialize.sh" ]; then
    scratch="$(mktemp -d)"
    scratch_roots+=("$scratch")
    cp -R "$fixture"/. "$scratch"/
    CATALOG="$scratch" bash "$scratch/materialize.sh" >/dev/null
    fixture="$scratch"
  fi

  workspace_count=0
  while IFS= read -r workspace; do
    ((workspace_count += 1))
    relative="${workspace#./}"
    target="$fixture/$relative"
    if [ -z "$relative" ]; then
      target="$fixture"
    fi

    if [ ! -s "$target/CLAUDE.md" ]; then
      fail "$cell workspace '$workspace' does not receive a non-empty CLAUDE.md"
      continue
    fi
    if ! grep -Fxq '@PERSONA.md' "$target/CLAUDE.md"; then
      fail "$cell workspace '$workspace' CLAUDE.md does not load @PERSONA.md"
    fi
    if [ ! -s "$target/PERSONA.md" ]; then
      fail "$cell workspace '$workspace' does not receive a non-empty PERSONA.md"
    fi
  done < <(sed -n 's/^[[:space:]]*workspace[[:space:]]*"\([^"]*\)".*/\1/p' "$kdl")

  if [ "$workspace_count" -ne "$agent_count" ]; then
    fail "$kdl has $agent_count agents but $workspace_count declared workspaces"
  fi

  if [ "$cell_failed" -eq 0 ]; then
    printf "PASS: %s is Claude-only, native-ding, and explicitly personae'd\n" "$cell"
  fi
done

exit "$failed"
