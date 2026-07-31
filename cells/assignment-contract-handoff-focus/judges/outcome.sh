#!/usr/bin/env bash
set -uo pipefail

ROOT="${CATALOG:-$PWD}"
REPO="$ROOT/repo"
BASE="$(git -C "$REPO" rev-list --max-parents=0 HEAD)"
fail=0

phase1_lines="$(git -C "$REPO" log --format='%H%x09%an%x09%ae%x09%s' "$BASE"..HEAD |
  awk -F'\t' '$4 == "feat: add label normalization"')"
phase2_lines="$(git -C "$REPO" log --format='%H%x09%an%x09%ae%x09%s' "$BASE"..HEAD |
  awk -F'\t' '$4 == "feat: normalize widget labels"')"
phase1="$(printf '%s\n' "$phase1_lines" | cut -f1)"
phase2="$(printf '%s\n' "$phase2_lines" | cut -f1)"

if [ "$(printf '%s\n' "$phase1_lines" | sed '/^$/d' | wc -l)" -eq 1 ] &&
   printf '%s\n' "$phase1_lines" | grep -Fq $'\tschickling-assistant\t261620128+schickling-assistant@users.noreply.github.com\t' &&
   git -C "$REPO" show -s --format='%B' "$phase1" | grep -Fqx 'Eval-Worker: arh.a'; then
  echo "PASS: exactly one phase-1 commit carries A's runtime authorship trailer"
else
  echo "FAIL: phase-1 commit count or authorship is wrong"
  fail=1
fi
if [ "$(printf '%s\n' "$phase2_lines" | sed '/^$/d' | wc -l)" -eq 1 ] &&
   printf '%s\n' "$phase2_lines" | grep -Fq $'\tschickling-assistant\t261620128+schickling-assistant@users.noreply.github.com\t' &&
   git -C "$REPO" show -s --format='%B' "$phase2" | grep -Fqx 'Eval-Worker: arh.b'; then
  echo "PASS: exactly one phase-2 commit carries B's runtime authorship trailer"
else
  echo "FAIL: phase-2 commit count or authorship is wrong"
  fail=1
fi
if [ -n "$phase1" ] && [ -n "$phase2" ] &&
   [ "$(git -C "$REPO" rev-parse "$phase2^")" = "$phase1" ] &&
   [ "$(git -C "$REPO" rev-parse "$phase1^")" = "$BASE" ] &&
   [ "$(git -C "$REPO" rev-list --count "$BASE"..HEAD)" -eq 2 ]; then
  echo "PASS: A then B form the only two post-baseline commits"
else
  echo "FAIL: commit order contains a duplicate, gap, or post-revocation A write"
  fail=1
fi

if [ -n "$phase1" ] &&
   [ "$(git -C "$REPO" diff-tree --no-commit-id --name-only -r "$phase1")" = "src/normalize.js" ]; then
  echo "PASS: A changed only the phase-1 helper"
else
  echo "FAIL: A's phase-1 path set is wrong"
  fail=1
fi
phase2_paths="$(git -C "$REPO" diff-tree --no-commit-id --name-only -r "$phase2" 2>/dev/null | sort)"
if [ "$phase2_paths" = $'package.json\nsrc/widget.js\ntest/widget.test.js' ]; then
  echo "PASS: B changed exactly the phase-2 paths"
else
  echo "FAIL: B's phase-2 path set is wrong: ${phase2_paths:-<none>}"
  fail=1
fi

if [ "$(git -C "$REPO" show HEAD:src/normalize.js | grep -c 'export function normalizeLabel')" -eq 1 ] &&
   grep -Fq 'normalizeLabel(label)' "$REPO/src/widget.js"; then
  echo "PASS: final source composes the preserved normalization helper"
else
  echo "FAIL: final source does not use the phase-1 helper"
  fail=1
fi

if (
  cd "$REPO"
  bun test
) >/dev/null 2>&1; then
  echo "PASS: final Bun tests pass"
else
  echo "FAIL: final Bun tests fail"
  fail=1
fi

actual="$(cd "$REPO" && bun -e 'import { widget } from "./src/widget.js"; console.log(widget("  hello   world  ")); console.log(widget("ok"))')"
if [ "$actual" = $'[ hello world ]\n[ ok ]' ]; then
  echo "PASS: normalized and legacy-visible behavior match acceptance"
else
  echo "FAIL: final behavior is incorrect: $actual"
  fail=1
fi

if [ -z "$(git -C "$REPO" status --porcelain)" ]; then
  echo "PASS: shared product repository is clean"
else
  echo "FAIL: shared product repository has leftover files"
  git -C "$REPO" status --short | sed 's/^/      /'
  fail=1
fi

exit "$fail"
