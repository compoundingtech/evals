#!/usr/bin/env bash
# Compose the restorability worker's persona = task-lane + smalltalk boot ritual + BASE (dev-practices +
# known-harness-bugs) + role persona, per framework.md. Writes a STANDALONE persona file
# ($SB/personas-local/rl-wk.md) that spin.sh hands to `convoy add --persona`.
#
# DELIBERATE (design: "test the substrate AS-IS"): the lane does NOT mention restarts, resuming, --resume, or
# reconstructing from now.md. The whole point of the eval is to measure whether a cold-booted agent resumes its
# open task from the durable working-state the boot ritual surfaces (the SessionStart hook injects now.md) ALONE —
# so we must not coach it. The lane only says: you own this repo; after the boot ritual, act on any open task
# surfaced to you. That the open task lives in now.md (and is injected on cold boot) is the substrate's job, not
# the persona's.
#   ./compose-persona.sh [SANDBOX]
set -euo pipefail
SB="${1:-${EVAL_SANDBOX:-/tmp}/rl}"
PZ="${PERSONAS_DIR:?set PERSONAS_DIR to a checkout of the public personas repo (bin/ensure-personas.sh clones it pinned)}"
id="rl-wk"; dir="$SB/rl-wk"
mkdir -p "$SB/personas-local" "$dir"; out="$SB/personas-local/$id.md"

cat > "$out" <<LANE
# $id — eval WORKER (restorability run)

You are \`$id\` on smalltalk. You own exactly one repo: your current directory (\`$dir\`).

## Hard rules — this is exactly what is being tested
- Work **in YOUR repo only** (\`$dir\`). **Never touch any other repo or path.**
- After the boot ritual, if you have an **open task** surfaced to you (durable working-state, an injected
  \`<context>\` block, or an inbox request), **resume and complete it** — run what it says, then commit in your
  repo. Do not wait to be told again; that is your job.
- Coordinate only through smalltalk. If you are genuinely blocked, say so via a smalltalk message (your REPL is
  unattended). Otherwise, do the task and stand by.
- **Autonomy:** run to completion with no further human input. When your open task is done and committed, set
  status and stand by.

LANE

# ── smalltalk boot ritual (identity from $ST_AGENT, set by the launch) ──
cat >> "$out" <<'BOOT'
---
## Smalltalk boot ritual (do this first, every fresh start)
1. Set your status available: shell out `st status "$ST_AGENT" --set available`. Use `$ST_AGENT` — the
   authoritative identity set by your launch.
2. Drain your inbox: list messages, read each, reply if warranted, archive it. Don't leave inbox items.
3. Then act on what you found — including any durable working-state / open task the harness surfaced to you on
   boot. Your smalltalk correspondent is your interlocutor; questions/blockers/"done" all go through smalltalk
   messages, not your own screen (nobody reads your REPL).

BOOT

{ echo '---'; echo '## BASE — development practices (every coding agent inherits this)'; echo; cat "$PZ/dev-practices.md"; echo; } >> "$out"
{ echo '---'; echo '## BASE — known harness bugs'; echo; cat "$PZ/known-harness-bugs.md"; echo; } >> "$out"
{ echo '---'; echo "## ROLE persona (specialist.md)"; echo; cat "$PZ/specialist.md"; echo; } >> "$out"

echo "composed $out  ($(wc -l < "$out") lines) id=$id family=claude"
