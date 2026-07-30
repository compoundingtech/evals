#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
input="$repo_root/cells/agent-new-bundle-contract/fixture/inputs/workspace-injection.json"
scratch="$(mktemp -d)"
cleanup() {
  rm -rf -- "$scratch"
}
trap cleanup EXIT

renderers=(
  "$repo_root/cells/agent-new-bundle-contract/fixture/render-intent.sh|$repo_root/cells/agent-new-bundle-contract/fixture/inputs/implementation-constraints.json"
  "$repo_root/cells/agent-new-interview/fixture/interviewer/render-intent.sh|$repo_root/cells/agent-new-interview/fixture/cases/implementation/hard-constraints.json"
)

for entry in "${renderers[@]}"; do
  renderer="${entry%%|*}"
  constraints="${entry#*|}"
  name="$(basename "$(dirname "$renderer")")"
  out="$scratch/$name"
  if bash "$renderer" "$input" "$out" /workspace/dotfiles "$constraints" >/dev/null 2>&1; then
    echo "FAIL: $renderer accepted a workspace KDL injection" >&2
    exit 1
  fi
  [ ! -e "$out/agents" ] || {
    echo "FAIL: $renderer emitted an Agent Spec after rejecting workspace KDL injection" >&2
    exit 1
  }
done

echo "PASS: both Agent Spec renderers reject workspace KDL injection before output"
