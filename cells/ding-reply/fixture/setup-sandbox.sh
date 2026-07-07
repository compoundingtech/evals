#!/usr/bin/env bash
# Materialize the ding-reply sandbox: a single agent's working dir with an ANSWER.txt the requester will ask it
# to read + reply with. Fully synthetic + hermetic. The point of this cell is the REPLY over the `st` CLI with
# NO MCP (the MCP-less config) — not a code task — so the "work" is deliberately trivial.
#   ./setup-sandbox.sh [SANDBOX]
set -euo pipefail
SB="${1:-${EVAL_SANDBOX:-./.sandbox}/ding-reply}"
rm -rf "$SB"; mkdir -p "$SB/work"
# The token the agent must read + reply with. Distinctive so the grader can assert it landed in the reply body.
# The grader reads it FROM here (not hardcoded), so this stays the single source of truth.
printf 'PONG-verify-7f3a91\n' > "$SB/work/ANSWER.txt"
echo "SANDBOX READY: $SB   (agent cwd=$SB/work; ANSWER.txt seeded)"
