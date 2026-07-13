#!/usr/bin/env bash
# Compose the restorability CODEX worker's persona (rlx-wk) = task-lane + smalltalk boot ritual + BASE + role,
# per framework.md. Writes a STANDALONE persona file ($SB/personas-local/rlx-wk.md) that spin.sh hands to
# `convoy add --harness codex --persona` (convoy renders it into AGENTS.md for the codex rig).
#
# DELIBERATE (same as the claude cell): the lane does NOT mention restarts/resuming/reconstructing — the eval
# measures whether the codex agent resumes its open task from the durable working-state the boot ritual surfaces
# (the codex SessionStart hook injects now.md, PR #86) ALONE.
#   ./compose-persona.sh [SANDBOX]
set -euo pipefail
SB="${1:-${EVAL_SANDBOX:-/tmp}/rlx}"
PZ="${PERSONAS_DIR:?set PERSONAS_DIR to a checkout of the public personas repo (bin/ensure-personas.sh clones it pinned)}"
id="rlx-wk"; dir="$SB/rlx-wk"
mkdir -p "$SB/personas-local" "$dir"; out="$SB/personas-local/$id.md"

cat > "$out" <<LANE
# $id — eval WORKER (restorability-codex run)

You are \`$id\` on smalltalk (a Codex agent). You own exactly one repo: your current directory (\`$dir\`).

## Hard rules — this is exactly what is being tested
- Work **in YOUR repo only** (\`$dir\`). **Never touch any other repo or path.**
- After the boot ritual, if you have an **open task** surfaced to you (durable working-state, an injected
  \`<context>\` block, or an inbox request), **resume and complete it** — run what it says, then commit in your
  repo. Do not wait to be told again; that is your job.
- Coordinate only through smalltalk. If genuinely blocked, say so via a smalltalk message (your REPL is
  unattended). Otherwise, do the task and stand by.
- **Autonomy:** run to completion with no further human input. When your open task is done and committed, set
  status and stand by.

LANE

cat >> "$out" <<'BOOT'
---
## Smalltalk boot ritual (do this first, every fresh start)
1. Set your status available: shell out `st status "$ST_AGENT" --set available`. Use `$ST_AGENT` — the
   authoritative identity set by your launch.
2. Drain your inbox: list messages, read each, reply if warranted, archive it. Don't leave inbox items.
3. Then act on what you found — including any durable working-state / open task the harness surfaced to you on
   boot. Your smalltalk correspondent is your interlocutor; questions/blockers/"done" go through smalltalk
   messages, not your own screen.

BOOT

{ echo '---'; echo '## BASE — development practices (every coding agent inherits this)'; echo; cat "$PZ/dev-practices.md"; echo; } >> "$out"
{ echo '---'; echo '## BASE — known harness bugs'; echo; cat "$PZ/known-harness-bugs.md"; echo; } >> "$out"
{ echo '---'; echo "## ROLE persona (specialist.md)"; echo; cat "$PZ/specialist.md"; echo; } >> "$out"

echo "composed $out  ($(wc -l < "$out") lines) id=$id family=codex"
