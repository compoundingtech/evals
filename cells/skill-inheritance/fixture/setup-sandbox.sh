#!/usr/bin/env bash
# Materialize the skill-inheritance sandbox: a worker repo carrying a PROJECT-scope skill
# (<repo>/.claude/skills/evalskill-project) + a standalone local PLUGIN (evalpkg, loaded via --plugin-dir)
# carrying a PLUGIN-scope skill (skills/evalskill-plugin). Each skill's body carries a per-run SECRET TOKEN
# and tells the agent to write that token to a sentinel file in its cwd. The token lives ONLY in the skill
# body — NEVER in the kick — so a sentinel bearing the right token evidences the worker actually LOADED +
# invoked that skill (it had no other way to learn the token). Fully synthetic + hermetic; touches NOTHING
# under ~/.claude (no personal-scope skills, no credentials) — both scopes live outside the config dir.
#   ./setup-sandbox.sh [SANDBOX]
set -euo pipefail
SB="${1:-${EVAL_SANDBOX:-./.sandbox}/skill-inheritance}"
rm -rf "$SB"; mkdir -p "$SB/.stev"

# --- per-run secret tokens (the ungameable proof each skill actually fired) --------------------------------
tok() { printf '%s-%s' "$1" "$(head -c 5 /dev/urandom | od -An -tx1 | tr -d ' \n')"; }
TOKEN_PROJECT="$(tok SIP)"   # SIP = Skill-Inheritance Project scope
TOKEN_PLUGIN="$(tok SIU)"    # SIU = Skill-Inheritance Union (plugin scope)
printf '%s\n' "$TOKEN_PROJECT" > "$SB/.stev/token-project"
printf '%s\n' "$TOKEN_PLUGIN"  > "$SB/.stev/token-plugin"

# --- helper: write a SKILL.md whose body writes <sentinel> containing <token> ------------------------------
write_skill() {  # <dir> <skill-name> <description> <sentinel-file> <token>
  local dir="$1" name="$2" desc="$3" sentinel="$4" token="$5"
  mkdir -p "$dir"
  cat > "$dir/SKILL.md" <<SKILL
---
name: $name
description: $desc
---

# $name

When you use this skill, perform EXACTLY this one action and nothing else:

Write the file \`$sentinel\` in your current working directory so that its entire contents are exactly:

\`\`\`
$token
\`\`\`

Concretely, run:

\`\`\`bash
printf '%s\\n' '$token' > $sentinel
\`\`\`

That is the whole task for this skill. Do not print the token anywhere else.
SKILL
}

# --- PROJECT scope: <repo>/.claude/skills/evalskill-project -----------------------------------------------
mkdir -p "$SB/repo"
write_skill "$SB/repo/.claude/skills/evalskill-project" \
  "evalskill-project" \
  "Eval harness: the PROJECT-scope inheritance probe. Use when asked to run the eval skill-inheritance check." \
  "SKILL_PROJECT.txt" "$TOKEN_PROJECT"

# --- PLUGIN scope: a standalone local plugin 'evalpkg' loaded via --plugin-dir ----------------------------
# Lives OUTSIDE the repo ($SB/plugin) — its path is never revealed to the worker, so the plugin token is
# only obtainable by invoking the (namespaced) plugin skill. Manifest + skills/<name>/SKILL.md layout.
mkdir -p "$SB/plugin/evalpkg/.claude-plugin"
cat > "$SB/plugin/evalpkg/.claude-plugin/plugin.json" <<'PJ'
{
  "name": "evalpkg",
  "description": "Eval harness local plugin: carries the PLUGIN-scope inheritance probe skill.",
  "version": "1.0.0"
}
PJ
write_skill "$SB/plugin/evalpkg/skills/evalskill-plugin" \
  "evalskill-plugin" \
  "Eval harness: the PLUGIN-scope (union) inheritance probe. Use when asked to run the eval skill-inheritance check." \
  "SKILL_PLUGIN.txt" "$TOKEN_PLUGIN"

# --- baseline commit (author-isolation reference) ---------------------------------------------------------
git -C "$SB/repo" init -q
git -C "$SB/repo" config user.name  "si-agent"
git -C "$SB/repo" config user.email "si-agent@eval.local"
git -C "$SB/repo" add -A && git -C "$SB/repo" commit -q -m "skill-inheritance: seed project-scope skill"

echo "SANDBOX READY: $SB"
echo "  PROJECT skill: $SB/repo/.claude/skills/evalskill-project/SKILL.md  (token in body only)"
echo "  PLUGIN  skill: $SB/plugin/evalpkg/skills/evalskill-plugin/SKILL.md (token in body only; loaded via --plugin-dir)"
echo "  worker cwd = $SB/repo; sentinels land here: SKILL_PROJECT.txt (project) + SKILL_PLUGIN.txt (plugin union)"
echo "  NOTHING written under ~/.claude/skills — personal scope untouched by construction."
