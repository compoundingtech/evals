#!/usr/bin/env bash
# JUDGE: docs written — the stub README was meaningfully expanded (README.md + any docs/ ≥ 25 lines),
# with at least one fenced code example (a worked example is a WARN if absent).
#
# PASS (exit 0): the docs are non-trivial (>= 25 lines).
set -uo pipefail
ROOT="${CATALOG:-$PWD}"; W="$ROOT/worker"
[ -d "$W" ] || { echo "FAIL: no worker repo at $W"; exit 1; }
DOCS=$(cd "$W" && { echo README.md; find docs -type f 2>/dev/null; } | sort -u)
BODY=$(cd "$W" && cat README.md $(find docs -type f 2>/dev/null) 2>/dev/null)
nlines=$(printf '%s\n' "$BODY" | wc -l | tr -d ' ')
if [ "$nlines" -ge 25 ]; then
  echo "PASS: docs written ($nlines lines across: $(echo $DOCS | tr '\n' ' '))"
else
  echo "FAIL: docs too thin ($nlines lines) — stub not meaningfully expanded"; exit 1
fi
printf '%s' "$BODY" | grep -q '```' && echo "  ok: includes a fenced code example" || echo "  WARN: no fenced code example found"
exit 0
