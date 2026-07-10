#!/usr/bin/env bash
# Materialize the inbox-hygiene sandbox: a single agent's git repo with an empty PROCESSED.log — the
# durable, COUNTABLE side-effect the grader uses to prove EXACTLY-ONCE processing. The "work" is trivial
# on purpose (append the message token); the eval is about the archive-after-act + resume-double-act
# hygiene, not a code task. Fully synthetic + hermetic.
#   ./setup-sandbox.sh [SANDBOX]
set -euo pipefail
SB="${1:-${EVAL_SANDBOX:-./.sandbox}/inbox-hygiene}"
rm -rf "$SB"; mkdir -p "$SB/repo"
: > "$SB/repo/PROCESSED.log"        # the ledger the agent appends each NEW message's token to (starts empty)
git -C "$SB/repo" init -q
git -C "$SB/repo" config user.name  "ih-agent"
git -C "$SB/repo" config user.email "ih-agent@eval.local"
git -C "$SB/repo" add -A && git -C "$SB/repo" commit -q -m "inbox-hygiene: empty PROCESSED.log"
echo "SANDBOX READY: $SB   (agent cwd=$SB/repo; PROCESSED.log empty; the grader counts token occurrences here)"
