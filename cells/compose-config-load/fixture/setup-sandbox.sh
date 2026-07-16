#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# Materialize the compose-config-load sandbox: a throwaway repo whose TRACKED CLAUDE.md carries a distinctive
# SECRET instruction and whose project skill carries a distinctive GREET token. A convoy agent composed into this
# repo must still LOAD both — its own CLAUDE.md (through convoy's additive CLAUDE.local.md layering, not clobbered)
# and the project skill. Each token lives ONLY in its file body (never in the kick), so a sentinel bearing the
# right token proves that file actually loaded + was followed. Short path (pty socket ~90-byte limit; use /tmp).
#   ./setup-sandbox.sh [SANDBOX_BASE]
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail
SB="${1:-${EVAL_SANDBOX:-/tmp}/ccl}"
rm -rf "$SB"; mkdir -p "$SB/.stev"
repo="$SB/repo"; mkdir -p "$repo/.claude/skills/greet"

# Per-run nonce so a PASS can't be pre-satisfied or recalled from training — but keep cos's recognizable prefixes.
nonce() { head -c 5 /dev/urandom | od -An -tx1 | tr -d ' \n'; }
SECRET="PURPLE-OTTER-42-$(nonce)"
GREET="AHOY-FROM-SKILL-$(nonce)"
printf '%s\n' "$SECRET" > "$SB/.stev/token-secret"
printf '%s\n' "$GREET"  > "$SB/.stev/token-greet"

# The repo's OWN tracked CLAUDE.md — the secret lives ONLY here. If convoy clobbers or fails to layer it, the
# agent can't produce SECRET.txt.
cat > "$repo/CLAUDE.md" <<CLAUDEMD
# compose-config-load test repo

## Project instruction (this file is the repo's own CLAUDE.md)
When someone asks you for "the secret" (or to write the secret), the secret is exactly:

    $SECRET

If asked to WRITE the secret, write that exact value (and nothing else) to a file named SECRET.txt in your
current working directory: \`printf '%s\\n' '$SECRET' > SECRET.txt\`.
CLAUDEMD

# The repo's OWN project skill — the greet token lives ONLY here.
cat > "$repo/.claude/skills/greet/SKILL.md" <<SKILL
---
name: greet
description: The project greeting skill. Use when asked to greet or to write the greeting.
---
# greet
When you use this skill, the greeting is exactly:

    $GREET

If asked to WRITE the greeting, write that exact value (and nothing else) to a file named GREET.txt in your
current working directory: \`printf '%s\\n' '$GREET' > GREET.txt\`.
SKILL

git -C "$repo" init -q
git -C "$repo" config user.name  "ccl-agent"
git -C "$repo" config user.email "ccl-agent@eval.local"
git -C "$repo" add -A && git -C "$repo" commit -q -m "compose-config-load: seed repo CLAUDE.md (secret) + greet skill (token)"

echo "SANDBOX READY: $SB"
echo "  repo CLAUDE.md secret token: $SECRET   (lives ONLY in CLAUDE.md)"
echo "  greet skill token:           $GREET    (lives ONLY in the skill body)"
echo "  worker cwd = $repo; sentinels land here: SECRET.txt (proves CLAUDE.md loaded) + GREET.txt (proves skill fired)"
