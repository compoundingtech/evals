#!/usr/bin/env bash
# Materialize the resumability sandbox: an agent's work dir with a PINNED .claude-session-id (an agent that
# already has a live session — exactly what the reboot migration preserves) + a prior-context marker. The cell
# probes `st launch`'s resume-vs-fresh behavior deterministically (via --dry-run). Fully synthetic + hermetic.
#   ./setup-sandbox.sh [SANDBOX]
set -euo pipefail
SB="${1:-${EVAL_SANDBOX:-./.sandbox}/resumability}"
rm -rf "$SB"; mkdir -p "$SB/work"
# A pinned session-id — the agent's EXISTING session, the thing the reboot migration preserves so agents keep
# their context. Fixed so the grader can assert `st launch` resumes exactly it.
printf 'resum-sid-7f3a91b2\n' > "$SB/work/.claude-session-id"
# A prior-context marker (for the live behavioral headline: a DEFAULT-resumed agent still knows this token; a
# --fresh agent must rehydrate from durable state and won't have it in-context).
printf 'PRIOR-CONTEXT-TOKEN: the-answer-is-42\n' > "$SB/work/CONTEXT.md"
echo "SANDBOX READY: $SB   (agent cwd=$SB/work; pinned .claude-session-id + CONTEXT.md)"
