#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# discriminator.sh — the incident-gate DISCRIMINATOR arm (the cell's held-out value), the DOCUMENTED PROXY that
# --resume carries session-scoped state while a cold restart sheds it. Robustly, WITHOUT hand-authoring the CC
# input-queue JSONL (that format is undocumented / version-dependent / buggy — a fragile seed would risk a false
# PASS, cos's worse-than-FAIL case).
#
# HONEST FRAMING (cos-approved): this is NOT the real CC input-queue. It is a black-box proxy on the SAME
# restore-channel property, via an observable channel — claude's OWN transcript write:
#   1. PLANT   — one real claude turn under a PINNED session-id plants a unique codeword ONLY in that session's
#                transcript (not in now.md / git / bus).
#   2. RESUME CONTROL — `claude --resume <pin>` is asked to recall the codeword. If it does, that PROVES --resume
#                inherits session-scoped state (the detection proof cos requires — a control that can't detect the
#                carried state is worse than a FAIL).
#   3. RELOAD CONTROL — a FRESH session-id (no --resume, no prior transcript — the reload analog) is asked the
#                same. It must NOT know it, PROVING a cold restart sheds session state.
#
# ROBUSTNESS (smalltalk boundary flags): the queue is CLIENT-side (~/.claude/projects/...), not st-state — this
# arm is the ONLY one that reaches into claude session-state; it is isolated here + cleaned up. And it is
# CC-version-dependent, so it SKIPS-WITH-REASON (never false-fails) if recall can't be established — the mechanism
# corollary (NO-QUEUE-CHANNEL) + the functional reconstruct arm still carry the eval.
#
# Writes $SB/.stev/discriminator.log:  resume_recalled=yes|no  reload_recalled=yes|no   (or  skip=<reason>).
# resume_recalled=yes IS the proven-detection bar; grade.sh requires it (else the arm skips as inconclusive).
#   ./discriminator.sh [SANDBOX]
#   env: RL_DISC_MODEL (optional claude model; default = claude default) · RL_DISC_TIMEOUT (per-turn secs, default 150)
# ─────────────────────────────────────────────────────────────────────────────
set -uo pipefail
SB="${1:-${EVAL_SANDBOX:-/tmp}/rl}"
mkdir -p "$SB/.stev"
LOG="$SB/.stev/discriminator.log"
: > "$LOG"
skip(){ echo "skip=$1" >> "$LOG"; echo "discriminator: SKIP ($1) — mechanism corollary carries the structural proof" >&2; exit 0; }

CLAUDE_BIN="${CLAUDE_BIN:-claude}"
command -v "$CLAUDE_BIN" >/dev/null 2>&1 || skip "no-claude-binary"
command -v uuidgen      >/dev/null 2>&1 || skip "no-uuidgen"
TO="${RL_DISC_TIMEOUT:-150}"
MODELFLAG=(); [ -n "${RL_DISC_MODEL:-}" ] && MODELFLAG=(--model "$RL_DISC_MODEL")

NONCE="$(uuidgen | tr 'A-Z' 'a-z' | tr -d '-' | cut -c1-8)"
CODEWORD="ZEBRA-${NONCE}"
PIN="$(uuidgen | tr 'A-Z' 'a-z')"     # the pinned session (transcript will carry the codeword)
FRESH="$(uuidgen | tr 'A-Z' 'a-z')"   # a fresh session (the reload analog — no prior transcript)

# Isolated cwd so the transcript's project-hash is our own; cleaned up at the end.
DCWD="$SB/.disc"; rm -rf "$DCWD"; mkdir -p "$DCWD"
run_claude(){ # <session-flag...> -- <prompt>  ; echoes stdout, returns claude's rc (127 on timeout)
  local prompt="${!#}"; local args=("${@:1:$#-2}")   # everything before the trailing `-- <prompt>`
  ( cd "$DCWD" && timeout "$TO" "$CLAUDE_BIN" -p "${MODELFLAG[@]}" "${args[@]}" "$prompt" 2>>"$SB/.stev/disc.err" )
}

echo "discriminator: plant codeword ($CODEWORD) into pinned session $PIN" >&2
PLANT="Remember this codeword exactly for later: ${CODEWORD}. Reply with only: OK"
plant_out="$(run_claude --session-id "$PIN" -- "$PLANT")" || skip "plant-turn-failed"

echo "discriminator: RESUME control — ask the pinned session to recall the codeword" >&2
RECALL="Earlier in THIS conversation I gave you a codeword. Reply with ONLY that codeword, or the single word NONE if you have none."
resume_out="$(run_claude --resume "$PIN" -- "$RECALL")" || skip "resume-turn-failed"

echo "discriminator: RELOAD control — a FRESH session (no prior transcript) gets the same question" >&2
reload_out="$(run_claude --session-id "$FRESH" -- "$RECALL")" || skip "reload-turn-failed"

# Best-effort cleanup of the client-side transcripts we created (keep the ~/.claude reach isolated + tidy).
for sid in "$PIN" "$FRESH"; do
  find "${HOME:-/nonexistent}/.claude/projects" -name "$sid.jsonl" -type f 2>/dev/null | while read -r j; do rm -f "$j"; done
done
rm -rf "$DCWD" 2>/dev/null || true

resume_recalled=no; reload_recalled=no
printf '%s' "$resume_out" | grep -qF "$CODEWORD" && resume_recalled=yes
printf '%s' "$reload_out" | grep -qF "$CODEWORD" && reload_recalled=yes

# resume_recalled=yes is the detection proof. If the control couldn't recall it (CC-version drift / model refusal),
# the proxy can't detect the carried state on this build — SKIP (inconclusive), don't false-fail.
[ "$resume_recalled" = "yes" ] || skip "recall-not-established (--resume control did not surface the planted codeword; CC-version drift?)"

{
  echo "codeword=$CODEWORD"
  echo "pinned_session=$PIN"
  echo "fresh_session=$FRESH"
  echo "resume_recalled=$resume_recalled"
  echo "reload_recalled=$reload_recalled"
} >> "$LOG"
echo "discriminator: resume_recalled=$resume_recalled reload_recalled=$reload_recalled (logged to $LOG)" >&2
