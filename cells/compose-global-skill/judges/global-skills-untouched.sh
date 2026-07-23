#!/usr/bin/env bash
# GLOBAL SKILLS UNTOUCHED (isolation): the user's global ~/.claude/skills (here a fake-HOME stand-in) is
# byte-identical before and after the compose — proving the eval only READ global skills, never wrote them.
set -uo pipefail
SB="${CATALOG:?CATALOG not set}"
b="$(cat "$SB/skills-before.md5" 2>/dev/null)"
a="$(cat "$SB/skills-after.md5" 2>/dev/null)"
[ -n "$b" ] || { echo "FAIL: no before-snapshot ($SB/skills-before.md5) — did the compose step run?"; exit 1; }
[ "$b" = "$a" ] || { echo "FAIL: global ~/.claude/skills CHANGED across the compose (before=$b after=$a) — the eval wrote the user's global skills"; exit 1; }
echo "PASS: global ~/.claude/skills byte-identical before/after — the compose only READ them, never wrote"
