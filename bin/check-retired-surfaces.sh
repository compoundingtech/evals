#!/usr/bin/env bash
# Reject active corpus/docs that depend on retired generators, compatibility roots, or wake sidecars.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

paths=(README.md SKILL.md AGENT-SPEC.md cells)
[ ! -f CATALOG.md ] || paths+=(CATALOG.md)
[ ! -d .claude/rules ] || paths+=(.claude/rules)
pattern='st2[[:space:]]+(render-agent|compile-agent|compose|add|remove|ding)|(^|[^[:alnum:]_-])convoy([^[:alnum:]_-]|$)|smalltalk|STBUS|\$CATALOG/smalltalk|--root|\.convoy'

if matches="$(rg --no-ignore -n -i "$pattern" "${paths[@]}" \
  -g '!**/_git/**' -g '!**/.git/**' 2>/dev/null)" && [ -n "$matches" ]; then
  echo "FAIL: active corpus/docs contain retired st2 or compatibility surfaces:" >&2
  printf '%s\n' "$matches" >&2
  exit 1
fi

echo "PASS: active corpus/docs contain no retired generator, compatibility-root, or wake-sidecar surface"
