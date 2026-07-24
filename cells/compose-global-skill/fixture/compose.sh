#!/usr/bin/env bash
# The whole box-free arm of compose-global-skill, as the eval's one `run { step "compose" }`. Proves an st2 COMPOSE
# (`st2 render-agent`) does NOT shadow/break a user's GLOBAL (~/.claude/skills) skills:
#   1. git-init a throwaway repo (render-agent git-excludes its overlay → needs a real git repo),
#   2. seed a GLOBAL skill under a FAKE HOME (the eval only READS global skills — never writes the real ~/.claude),
#   3. COMPOSE the agent into the repo on the DEFAULT config dir (no --config-dir — the standard case),
#   4. snapshot the fake global skills BEFORE + AFTER so a judge can prove the compose only read them.
# The rendered artifacts ($CATALOG/cat/<host>/gsw/agent.kdl + $CATALOG/repo/.claude/*) are what the held-out
# judges inspect for the no-shadow invariant. Deterministic, offline, public-safe.
set -euo pipefail
SB="${CATALOG:?CATALOG must be set — st2 eval provides it to run steps}"
cd "$SB"
rm -rf repo cat fakehome skills-before.md5 skills-after.md5

echo "== a throwaway git repo to compose into (it lacks the skill) =="
mkdir -p repo
git -C repo init -q -b main
echo "# throwaway repo (lacks the demo skill)" > repo/README.md
git -C repo add -A
git -C repo -c user.name="eval" -c user.email="eval@local" commit -q -m "init"

echo "== seed a GLOBAL (user-level) skill under a FAKE HOME — read-only; the real ~/.claude is never touched =="
mkdir -p fakehome/.claude/skills/demo-skill
printf '# demo-skill\nWhen asked about the demo domain, use the executable: acmebuild\n' \
  > fakehome/.claude/skills/demo-skill/SKILL.md
( cd fakehome/.claude/skills && find . -type f | sort | xargs md5sum ) | md5sum > skills-before.md5

echo "== COMPOSE: render the agent into the repo on the DEFAULT config dir (no --config-dir) =="
# HOME override points at the fake global skills — if render-agent touched ~/.claude it would show in the after-hash.
HOME="$SB/fakehome" st2 render-agent --identity gsw --dir "$SB/repo" --persona "$SB/persona.md" --harness claude "$SB/cat"

( cd fakehome/.claude/skills && find . -type f | sort | xargs md5sum ) | md5sum > skills-after.md5
echo "== composed: catalog=$SB/cat, overlay in $SB/repo; global skills before/after captured =="
