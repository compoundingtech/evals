#!/usr/bin/env bash
# Compose a minimal crash-ding persona. The crash-ding eval is about the SUBSTRATE (a real harness session dying
# → convoy up emits a crash ding), NOT about any agent task — so every role gets a tiny boot-and-idle lane:
# boot ritual (set status available, drain inbox) then stand by. Harness-agnostic: convoy add --harness
# claude|codex installs its own CLAUDE.md/AGENTS.md + boot hooks from this --persona lane, so the SAME lane
# drives a real claude OR codex session (that's the point — the ding must fire for both).
#   ./compose-persona.sh <cos|sup|worker> <id> [SANDBOX]
set -euo pipefail
role="$1"; id="$2"; SB="${3:-${EVAL_SANDBOX:-./.sandbox}/crash-ding}"
mkdir -p "$SB/personas-local"; out="$SB/personas-local/$id.md"

case "$role" in
  cos)    what="the chief-of-staff for this isolated test network. Crash dings about crashed members are delivered to your inbox." ;;
  sup)    what="a supervisor overseeing a worker on this network. If a member you own crashes, convoy delivers a crash ding to your inbox." ;;
  worker) what="a worker on this network. Your only job is to exist: boot, go idle, and stay up until something stops you." ;;
  *) echo "role must be cos|sup|worker" >&2; exit 1 ;;
esac

cat > "$out" <<LANE
# $id — crash-ding eval $role (minimal boot-and-idle)

You are \`$id\` on smalltalk (ding — no MCP; all bus ops via the \`st\` CLI). You are $what

## What to do
This is a substrate/durability test — there is no task to perform. Just:
1. Boot ritual: set your status available (\`st status "\$ST_AGENT" --set available\`, using \`\$ST_AGENT\`) and
   drain your inbox (read → act only if a message truly needs it → archive).
2. Then stand by / idle. Do not spawn anything, do not poll — just remain available.

Your correspondent, if any, is on the bus, not your REPL. Nobody reads your terminal.
LANE
echo "composed $out ($role/$id, $(wc -l < "$out") lines)"
