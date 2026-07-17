#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# probe.sh (compose-global-skill) — DETERMINISTIC, box-free. Proves the convoy compose does NOT SHADOW or BREAK
# global-skill discovery, so a user's ~/.claude/skills stay callable in a composed session. Captures:
#   pty-env.txt    — the [sessions.claude.env] convoy writes: it must NOT set CLAUDE_CONFIG_DIR (so the agent uses
#                    the DEFAULT config dir, where global skills live — the compose does not relocate skill scope).
#   reload-cmd.txt — the launch command: must NOT carry --config-dir (relocate) or --disable-slash-commands
#                    (which "Disable all skills").
#   settings.txt   — convoy's .claude/settings.local.json: must be ADDITIVE (hooks only), touching NO skill key
#                    (no disableAllSkills / skill scoping) that would suppress global-skill discovery.
#   real-skills-before.txt — a baseline of the real ~/.claude/skills, so grade.sh confirms the eval touched it NOT.
#
# The compose runs with the DEFAULT config dir (no --config-dir) — exactly the standard case. Isolated net; torn down.
#   ./probe.sh [SANDBOX]
# ─────────────────────────────────────────────────────────────────────────────
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/../../../bin/lib-harness.sh"
SB="${1:-${EVAL_SANDBOX:-/tmp}/gs}"
[ -d "$SB/repo/.git" ] || { echo "== sandbox absent — materializing =="; "$HERE/setup-sandbox.sh" "$SB" >/dev/null; }
repo="$SB/repo"; NET="$SB/net"; P="$SB/.probe"; rm -rf "$P"; mkdir -p "$P"
id="gsw"

# Baseline the real ~/.claude/skills BEFORE anything — the isolation gate confirms it is byte-identical after.
ls -1 "${HOME:-/nonexistent}/.claude/skills" 2>/dev/null | sort > "$P/real-skills-before.txt" || true

if ! command -v convoy >/dev/null 2>&1; then
  echo "SKIP: convoy not on PATH" >&2; printf 'CONVOY-MISSING\n' > "$P/pty-env.txt"; exit 0
fi

printf '# global-skill worker %s\nYou are %s.\n' "$id" "$id" > "$P/persona.md"
export ST_ROOT="$NET"; export PTY_ROOT="$NET/pty"
trap 'stev_convoy_teardown "$NET" >/dev/null 2>&1 || true' EXIT INT TERM

echo "== compose into the repo (DEFAULT config dir — the standard case) =="
stev_convoy_init "$NET" >/dev/null 2>&1 || true
convoy add worker --identity "$id" --network "$NET" --dir "$repo" --persona "$P/persona.md" --harness claude >"$P/add.out" 2>&1
echo "   add rc=$?"

echo "== capture: does the compose relocate the config dir / disable skills / scope skills away? =="
sed -n '/\[sessions.claude.env\]/,/^\[/p' "$repo/pty.toml" > "$P/pty-env.txt" 2>/dev/null
grep -E '^command = ' "$repo/pty.toml" | head -1 > "$P/reload-cmd.txt" 2>/dev/null || true
cp "$repo/.claude/settings.local.json" "$P/settings.txt" 2>/dev/null || printf '(no settings.local.json)\n' > "$P/settings.txt"
{
  grep -qiE 'CLAUDE_CONFIG_DIR' "$P/pty-env.txt"                         && echo "env_sets_config_dir=yes"    || echo "env_sets_config_dir=no"
  grep -qiE -- '--config-dir|--disable-slash-commands' "$P/reload-cmd.txt" && echo "cmd_relocates_or_disables=yes" || echo "cmd_relocates_or_disables=no"
  grep -qiE 'disableAllSkills|"skills"|disable.*slash' "$P/settings.txt"  && echo "settings_touches_skills=yes"  || echo "settings_touches_skills=no"
} > "$P/no-shadow.txt"
sed 's/^/     /' "$P/no-shadow.txt"

echo "== probe artifacts in $P/ =="; ls -1 "$P" | sed 's/^/     /'
echo "GRADE:  $HERE/grade.sh \"$SB\""
