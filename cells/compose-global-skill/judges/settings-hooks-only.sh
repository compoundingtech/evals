#!/usr/bin/env bash
# SETTINGS ADDITIVE (hooks only) + MUTATION-VALID: the rendered .claude/settings.local.json must be additive — it
# carries the boot hooks (SessionStart present → render wrote real settings) and touches NO skill-scoping key that
# would suppress the user's global skills. The SAME shadow-detector is then run against a synthetic shadowed
# settings and MUST bite it — proving this check discriminates (it is not always-pass).
set -uo pipefail
SB="${CATALOG:?CATALOG not set}"
s="$SB/repo/.claude/settings.local.json"
[ -f "$s" ] || { echo "FAIL: no .claude/settings.local.json rendered into the workspace"; exit 1; }

# A shadow = any key that relocates the config dir, disables slash commands, or scopes skills away.
shadowed(){ grep -qiE 'disableAllSkills|"skills"|--disable-slash-commands|CLAUDE_CONFIG_DIR|--config-dir' "$1"; }

# (a) the REAL settings must NOT be shadowed
if shadowed "$s"; then echo "FAIL: settings.local.json touches a skill-scoping / config-relocation key — could suppress global skills"; exit 1; fi
# (b) it must actually carry the boot hooks (not an empty/absent-key pass)
grep -q '"SessionStart"' "$s" || { echo "FAIL: settings.local.json lacks the SessionStart hook — render did not write the real additive settings"; exit 1; }
# (c) MUTATION-VALID: the detector must FLAG a synthetic shadowed settings
tmp="$(mktemp)"; printf '{ "disableAllSkills": true }\n' > "$tmp"
if ! shadowed "$tmp"; then case "$tmp" in /tmp/*) rm -f "$tmp";; esac; echo "FAIL: the shadow-detector did NOT flag a synthetic disableAllSkills — the check is broken (always-pass)"; exit 1; fi
case "$tmp" in /tmp/*) rm -f "$tmp";; esac
echo "PASS: settings.local.json is additive (SessionStart hook present, no skill-scoping/config key) AND the detector provably bites a synthetic shadow (mutation-valid)"
