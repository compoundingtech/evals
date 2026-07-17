#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# Materialize the compose-global-skill sandbox. Proves a GLOBAL (user-level ~/.claude/skills) skill still fires
# through a convoy compose — the distinct case from compose-config-load (repo-local skill).
#
# LIVE ARM = READ-ONLY existing-skill (Nathan's approach; supersedes the config-dir/auth-key routes): use a skill
# ALREADY in ~/.claude/skills, on the DEFAULT config dir (real keychain auth works — no key, no relocation, no
# install, nothing to clean up, ZERO touch of the user's config). The distinctive assertion string comes from that
# skill's OWN body (not the kick), so a correct answer can only be the skill firing.
#
# Produces:
#   $SB/repo             a throwaway repo that does NOT contain the skill (the agent is composed here).
#   $SB/.stev/skill      the chosen global skill name (or empty => live arm skips, NO-SHADOW core carries it).
#   $SB/.stev/assert     the distinctive string the agent must produce ONLY by loading that skill.
#   $SB/.stev/domain     the domain the kick asks about (never names the assert string).
# Short path (pty socket ~90-byte limit).
#   ./setup-sandbox.sh [SANDBOX_BASE]
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail
SB="${1:-${EVAL_SANDBOX:-/tmp}/gs}"
rm -rf "$SB"; mkdir -p "$SB/.stev"

repo="$SB/repo"; mkdir -p "$repo"
printf '# compose-global-skill test repo\n\nThis repo has NO skills of its own. Any skill the agent fires must be a\nGLOBAL (user-level ~/.claude/skills) skill discovered through the compose.\n' > "$repo/CLAUDE.md"
git -C "$repo" init -q
git -C "$repo" config user.name  "gs-agent"
git -C "$repo" config user.email "gs-agent@eval.local"
git -C "$repo" add -A && git -C "$repo" commit -q -m "compose-global-skill: seed repo (no repo-local skill)"

# Choose the global skill to prove. Supported: xcodebuildmcp-cli (its body mandates the `xcodebuildmcp` executable
# instead of raw xcodebuild — a distinctive answer a skill-less agent would NOT give). Present on Nathan's box + CI
# dev boxes. If absent, the live arm skips-with-reason (portability) and the box-free NO-SHADOW core carries it.
skills_dir="${HOME:-/nonexistent}/.claude/skills"
skill=""; assert=""; domain=""
if [ -f "$skills_dir/xcodebuildmcp-cli/SKILL.md" ]; then
  skill="xcodebuildmcp-cli"; assert="xcodebuildmcp"
  domain="the single command-line executable you should use for iOS/macOS/Xcode build, test, and run work"
fi
printf '%s\n' "$skill"  > "$SB/.stev/skill"
printf '%s\n' "$assert" > "$SB/.stev/assert"
printf '%s\n' "$domain" > "$SB/.stev/domain"

echo "SANDBOX READY: $SB"
echo "  repo (no local skill): $repo"
if [ -n "$skill" ]; then
  echo "  GLOBAL skill under test (read-only, NOT modified): ~/.claude/skills/$skill  assert-string=$assert"
else
  echo "  no supported global skill in ~/.claude/skills — the LIVE arm will SKIP; the NO-SHADOW core carries the proof."
fi
