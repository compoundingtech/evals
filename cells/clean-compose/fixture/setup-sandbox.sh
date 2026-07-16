#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# Materialize the clean-compose sandbox: a throwaway git repo that carries its OWN CLAUDE.md + a project-scope
# skill, committed CLEAN. probe.sh then `convoy add`s an agent INTO this repo and checks that convoy did not
# pollute it (git status --porcelain must be EMPTY). Short path on purpose — the pty unix-socket path is limited
# (~90 bytes; a deep $NET/pty/silber.<id>.ding.sock must fit), so keep $SB short (use /tmp, NOT a long scratchpad).
#   ./setup-sandbox.sh [SANDBOX_BASE]
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail
SB="${1:-${EVAL_SANDBOX:-/tmp}/cc}"
rm -rf "$SB"; mkdir -p "$SB"
repo="$SB/repo"; mkdir -p "$repo/.claude/skills/greet"

# The repo's OWN tracked config (what must survive the compose untouched + not be polluted).
printf '# clean-compose test repo\n\nThis repo has its own CLAUDE.md and a project skill. A convoy agent composed\ninto it must add ZERO tracked/untracked pollution to `git status --porcelain`.\n' > "$repo/CLAUDE.md"
cat > "$repo/.claude/skills/greet/SKILL.md" <<'SKILL'
---
name: greet
description: A trivial project-scope skill used to prove the repo composes cleanly.
---
# greet
When asked to greet, reply exactly: AHOY-FROM-SKILL
SKILL

git -C "$repo" init -q
git -C "$repo" config user.name  "cc-agent"
git -C "$repo" config user.email "cc-agent@eval.local"
git -C "$repo" add -A && git -C "$repo" commit -q -m "clean-compose: seed repo with its own CLAUDE.md + greet skill"

# Sanity: the repo is CLEAN at seed (so any dirt after the compose is convoy's, not ours).
if [ -n "$(git -C "$repo" status --porcelain)" ]; then
  echo "setup: FATAL — seed repo is not clean; fix the fixture" >&2; git -C "$repo" status --porcelain >&2; exit 1
fi

echo "$SB"
echo "SANDBOX READY: $SB   (clean committed repo at $repo; net will be $SB/net; probe.sh does the compose + porcelain check)" >&2
