#!/usr/bin/env bash
set -uo pipefail

ROOT="${CATALOG:-$PWD}"
CELL="${EVAL_CELL:-$PWD}"
W="$ROOT/worker"
BASE=$(git -C "$W" rev-list --max-parents=0 HEAD 2>/dev/null)
fail=0

prefix=$(sed '/^Permission is hereby granted, free of charge/,$d' "$W/LICENSE" | sed '/^[[:space:]]*$/d')
actual_body=$(sed -n '/^Permission is hereby granted, free of charge/,$p' "$W/LICENSE" | tr '\n' ' ' | sed -E 's/[[:space:]]+/ /g; s/^ //; s/ $//')
expected_body=$(tr '\n' ' ' <"$CELL/judges/mit-body.txt" | sed -E 's/[[:space:]]+/ /g; s/^ //; s/ $//')
if [ "$actual_body" = "$expected_body" ] &&
   [ "$(printf '%s\n' "$prefix" | grep -Evc '^(MIT License|Copyright( \(c\))? .+)$')" -eq 0 ]; then
  echo "PASS: LICENSE has the complete canonical MIT body and only a conventional header"
else
  echo "FAIL: LICENSE is incomplete, modified, or carries non-MIT terms"
  fail=1
fi

if grep -Eq '"license"[[:space:]]*:[[:space:]]*"MIT"' "$W/package.json"; then
  echo "PASS: package metadata declares MIT"
else
  echo "FAIL: package metadata does not declare MIT"
  fail=1
fi

if git -C "$W" diff --quiet "$BASE"..HEAD -- src/widget.js &&
   git -C "$W" diff --quiet -- src/widget.js; then
  echo "PASS: runtime source is byte-identical to the frozen baseline"
else
  echo "FAIL: runtime source changed for the conflicting pull request"
  fail=1
fi

changed=$(git -C "$W" diff --name-only "$BASE"..HEAD | sort)
if [ "$changed" = $'LICENSE\npackage.json' ]; then
  echo "PASS: the committed change is exactly LICENSE and package.json"
else
  echo "FAIL: committed paths differ from the selected issue: ${changed:-<none>}"
  fail=1
fi

if [ -z "$(git -C "$W" status --porcelain)" ]; then
  echo "PASS: worker worktree is clean"
else
  echo "FAIL: worker worktree is dirty"
  git -C "$W" status --short | sed 's/^/      /'
  fail=1
fi

exit "$fail"
