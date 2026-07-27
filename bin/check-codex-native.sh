#!/usr/bin/env bash
# Compatibility entrypoint: verify the complete maintained Codex surface, not a handpicked cell list.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [ "$#" -gt 0 ]; then
  printf 'NOTE: per-cell arguments are ignored; the maintained Codex corpus is checked as one contract\n'
fi

"$repo_root/bin/check-model-policy.sh"
"$repo_root/bin/check-event-first.sh"
"$repo_root/bin/check-harness-contract.sh" --harness Codex
