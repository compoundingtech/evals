#!/usr/bin/env bash
# Compose the compose-global-skill worker persona = task-lane + boot ritual + BASE + role. Names NO token.
#   ./compose-persona.sh [SANDBOX] [ID] [DIR]   # defaults: ID=gsw DIR=$SB/repo (control: gsnc + $SB/control)
set -euo pipefail
SB="${1:-${EVAL_SANDBOX:-/tmp}/gs}"
PZ="${PERSONAS_DIR:?set PERSONAS_DIR to a checkout of the public personas repo (bin/ensure-personas.sh clones it pinned)}"
id="${2:-gsw}"; dir="${3:-$SB/repo}"
mkdir -p "$SB/personas-local" "$dir"; out="$SB/personas-local/$id.md"

cat > "$out" <<LANE
# $id — eval WORKER (compose-global-skill run)

You are \`$id\` on smalltalk. You own exactly one repo: your current directory (\`$dir\`).

## Hard rules — this is exactly what is being tested
- Work **in YOUR repo only** (\`$dir\`). **Never touch any other repo or path.**
- You have access to your usual **skills** (including any installed at the user/global level). When your inbox
  task asks you to use a named skill, **use it** and follow its instructions exactly.
- After the boot ritual, do the task in your inbox exactly as asked, then reply on the thread that it is done.
- Coordinate only through smalltalk. **Autonomy:** run to completion with no further human input.

LANE

cat >> "$out" <<'BOOT'
---
## Smalltalk boot ritual (do this first, every fresh start)
1. Set your status available: shell out `st status "$ST_AGENT" --set available`. Use `$ST_AGENT`.
2. Drain your inbox: list messages, read each, reply if warranted, archive it.
3. Then act on what you found.

BOOT

# Role file: personas repo renamed specialist.md -> worker.md; prefer worker.md, fall back to specialist.md
# (the repo's pinned personas still ship specialist.md). Fail LOUD if neither exists.
role_md="$PZ/worker.md"; [ -f "$role_md" ] || role_md="$PZ/specialist.md"
[ -f "$role_md" ] || { echo "compose-persona: FATAL — no leaf role persona (worker.md or specialist.md) in $PZ. Run bin/ensure-personas.sh." >&2; exit 1; }
{ echo '---'; echo '## BASE — development practices'; echo; cat "$PZ/dev-practices.md"; echo; } >> "$out"
{ echo '---'; echo '## BASE — known harness bugs'; echo; cat "$PZ/known-harness-bugs.md"; echo; } >> "$out"
{ echo '---'; echo "## ROLE persona ($(basename "$role_md"))"; echo; cat "$role_md"; echo; } >> "$out"

echo "composed $out  ($(wc -l < "$out") lines) id=$id family=claude"
