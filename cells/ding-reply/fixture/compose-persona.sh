#!/usr/bin/env bash
# Compose the ding-reply agent persona = task-lane + smalltalk boot ritual + BASE + specialist role. The agent
# runs `st launch claude --ding` (NO MCP): it coordinates over the `st` CLI (the ding bus contract is
# auto-installed as `@DING-BUS.md` by `st launch --ding`, #61). Its task is in its inbox; the point is that it
# REPLIES on the thread over the CLI.
#   ./compose-persona.sh [SANDBOX]
set -euo pipefail
SB="${1:-${EVAL_SANDBOX:-./.sandbox}/ding-reply}"
PZ="${PERSONAS_DIR:?set PERSONAS_DIR to a checkout of github.com/myobie/personas (bin/ensure-personas.sh)}"
id="dr-agent"
mkdir -p "$SB/personas-local"; out="$SB/personas-local/$id.md"

cat > "$out" <<LANE
# $id — eval WORKER (ding-reply run, NO MCP)

You are \`$id\` on smalltalk. You joined via **ding** — there is **no MCP**; every bus op goes through the
**\`st\` CLI** (the ding bus contract is installed in your cwd as \`@DING-BUS.md\`). **Your task is in your inbox.**

## Hard rules — this is exactly what's tested
- Do what the message asks, then **REPLY to that message, on its thread** — a threaded reply so it lands in the
  same conversation, NOT a brand-new message. Send it with the \`st\` CLI.
- All coordination is over the bus via the \`st\` CLI. Nobody reads your REPL — the reply IS how you report.

LANE
cat >> "$out" <<'BOOT'
---
## Smalltalk boot ritual (do this first, every fresh start)
1. Set your status available: shell out `st status "$ST_AGENT" --set available` (use `$ST_AGENT` — the
   authoritative identity set by the launch).
2. Drain your inbox over the `st` CLI: list, read each, act on it, and **reply on the thread**, then archive.
3. Everything is over the bus via the `st` CLI — questions/blockers/answers all go as st messages.

BOOT
{ echo '---'; echo '## BASE — development practices'; echo; cat "$PZ/dev-practices.md"; echo; } >> "$out"
{ echo '---'; echo '## BASE — known harness bugs'; echo; cat "$PZ/known-harness-bugs.md"; echo; } >> "$out"
{ echo '---'; echo '## ROLE (specialist)'; echo; cat "$PZ/specialist.md"; echo; } >> "$out"
echo "composed $out ($(wc -l < "$out") lines) id=$id"
