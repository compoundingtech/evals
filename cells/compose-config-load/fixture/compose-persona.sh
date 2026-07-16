#!/usr/bin/env bash
# Compose the compose-config-load worker's persona (ccl) = task-lane + smalltalk boot ritual + BASE + role, per
# framework.md. Writes a STANDALONE persona ($SB/personas-local/ccl.md) that spin.sh hands to `convoy add
# --persona` (convoy installs it as PERSONA.md + @-imports it from the CLAUDE.local.md it writes).
#
# DELIBERATE: the lane names NEITHER token (the secret in CLAUDE.md nor the greet token in the skill). The whole
# point is that the agent produces them ONLY by loading its own repo CLAUDE.md + the project skill through the
# compose — so the lane must not leak them.
#   ./compose-persona.sh [SANDBOX]
set -euo pipefail
SB="${1:-${EVAL_SANDBOX:-/tmp}/ccl}"
PZ="${PERSONAS_DIR:?set PERSONAS_DIR to a checkout of the public personas repo (bin/ensure-personas.sh clones it pinned)}"
id="ccl"; dir="$SB/repo"
mkdir -p "$SB/personas-local" "$dir"; out="$SB/personas-local/$id.md"

cat > "$out" <<LANE
# $id — eval WORKER (compose-config-load run)

You are \`$id\` on smalltalk. You own exactly one repo: your current directory (\`$dir\`).

## Hard rules — this is exactly what is being tested
- Work **in YOUR repo only** (\`$dir\`). **Never touch any other repo or path.**
- Your repo has its OWN instructions (its CLAUDE.md) and its OWN skills. **Follow your repo's instructions and
  use its skills** when your inbox task calls for them.
- After the boot ritual, do the task in your inbox exactly as asked, then reply on the thread that it is done.
- Coordinate only through smalltalk. If genuinely blocked, say so via a smalltalk message (your REPL is
  unattended). **Autonomy:** run to completion with no further human input.

LANE

cat >> "$out" <<'BOOT'
---
## Smalltalk boot ritual (do this first, every fresh start)
1. Set your status available: shell out `st status "$ST_AGENT" --set available`. Use `$ST_AGENT`.
2. Drain your inbox: list messages, read each, reply if warranted, archive it.
3. Then act on what you found. Your smalltalk correspondent is your interlocutor; questions/blockers/"done" go
   through smalltalk messages, not your own screen.

BOOT

{ echo '---'; echo '## BASE — development practices (every coding agent inherits this)'; echo; cat "$PZ/dev-practices.md"; echo; } >> "$out"
{ echo '---'; echo '## BASE — known harness bugs'; echo; cat "$PZ/known-harness-bugs.md"; echo; } >> "$out"
{ echo '---'; echo "## ROLE persona (specialist.md)"; echo; cat "$PZ/specialist.md"; echo; } >> "$out"

echo "composed $out  ($(wc -l < "$out") lines) id=$id family=claude"
