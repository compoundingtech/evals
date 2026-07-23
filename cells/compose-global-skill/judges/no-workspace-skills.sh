#!/usr/bin/env bash
# NO WORKSPACE SKILLS SHADOW: the compose overlay wrote NO workspace-level .claude/skills. A workspace skills dir
# would take precedence over the user's global ~/.claude/skills and mask them in the composed session.
set -uo pipefail
SB="${CATALOG:?CATALOG not set}"
[ -e "$SB/repo/.claude/skills" ] && { echo "FAIL: the overlay wrote a workspace .claude/skills — it would shadow the user's global skills"; exit 1; }
echo "PASS: the overlay wrote NO workspace .claude/skills — nothing masks the user's global ~/.claude/skills"
