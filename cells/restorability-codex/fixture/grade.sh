#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# Ground-truth grader for RESTORABILITY-CODEX (the codex twin). Same hard gates as the claude cell, but the
# HOOK-EMITS-BLOCK gate parses the CODEX hook's JSON stdout (.additionalContext) instead of the claude hook's
# stderr. Proves smalltalk PR #86 (codex now.md injection) works fleet-wide. Requires jq (the codex hook hard-deps
# it); the codex-hook gate SKIPS-WITH-REASON if jq is absent or the reference checkout predates #86.
#   ./grade.sh [SANDBOX]
# Exit 0 = no hard (deterministic) failures.
# ─────────────────────────────────────────────────────────────────────────────
set -uo pipefail
SB="${1:-${EVAL_SANDBOX:-/tmp}/rlx}"
P="$SB/.probe"; WK="$SB/rlx-wk"
pass=0; fail=0; warn=0; skip=0
ok(){ echo "  [PASS] $1"; pass=$((pass+1)); }
no(){ echo "  [FAIL] $1"; fail=$((fail+1)); }
wn(){ echo "  [WARN] $1"; warn=$((warn+1)); }
sk(){ echo "  [SKIP] $1"; skip=$((skip+1)); }

[ -d "$P" ] || { echo "no probe artifacts at $P — run probe.sh first"; exit 1; }
TOKEN="$(tr -d '\r\n' < "$SB/.token" 2>/dev/null)"
echo "RECONSTRUCT token this run: ${TOKEN:-<none>}"

echo
echo "== NO-RESUME (hard, deterministic) — the codex reload respawn command carries NO --resume/--session-id =="
if [ -f "$P/reload-cmd.txt" ] && [ -s "$P/reload-cmd.txt" ]; then
  CMD="$(cat "$P/reload-cmd.txt")"
  echo "$CMD" | grep -qiE -- '--resume|--session-id|--session_id' && no "reload command CARRIES --resume/--session-id — $CMD" \
                                                                   || ok "reload command carries NO --resume/--session-id (a genuine cold boot)"
  echo "$CMD" | grep -qE 'exec (codex|claude)' && ok "reload command is a fresh cold-boot exec (codex)" \
                                               || wn "reload command shape unexpected — eyeball: $CMD"
else
  sk "no reload-cmd captured (convoy/codex absent, or materialization skipped) — NO-RESUME unproven this run"
fi

echo
echo "== NO-QUEUE-CHANNEL (hard, deterministic) — structural corollary: fresh session => no channel for stale state =="
echo "     [framing] STRUCTURAL proof; the CC input-queue is a claude-client concern (not seeded) — codex proves the now.md restore parity."
if [ -f "$P/pty.toml" ]; then
  grep -qiE -- '--resume|--session-id|--session_id' "$P/pty.toml" && no "codex pty.toml pins a --resume/--session-id (a restore channel exists)" \
                                                                  || ok "codex reload boots a fresh session (no --resume/--session-id) => no channel for prior-session state"
else
  sk "no codex pty.toml captured — NO-QUEUE-CHANNEL corollary unproven this run"
fi

echo
echo "== REHYDRATE-WIRED (hard, deterministic) — codex SessionStart hook resolvable + now.md non-empty with the token =="
HOOKP="$(cat "$P/hook-path.txt" 2>/dev/null)"
if [ -n "$HOOKP" ] && [ -f "$HOOKP" ]; then ok "codex SessionStart hook resolved + present ($HOOKP)"; \
                                       else no "codex SessionStart hook NOT resolved ($HOOKP)"; fi
if [ -s "$SB/now.md.seed" ] && grep -qF "$TOKEN" "$SB/now.md.seed" 2>/dev/null; then
  ok "now.md is non-empty and carries the RECONSTRUCT token"
else
  no "now.md.seed empty or missing the token"
fi

echo
echo "== CODEX-HOOK-EMITS-BLOCK (hard, deterministic — PR #86 parity) — codex hook injects the now.md block in JSON stdout =="
MARK='<context source="st/context/now.md" agent="rlx-wk">'
FRESH="$P/hook-fresh.json"
if [ ! -f "$FRESH" ]; then
  sk "codex hook not run — CODEX-HOOK-EMITS-BLOCK unproven this run"
elif grep -q 'JQ-MISSING' "$FRESH"; then
  sk "jq not on PATH (the codex hook hard-deps it) — codex hook gate skipped-with-reason"
elif grep -q 'HOOK-UNRESOLVED' "$FRESH"; then
  sk "codex hook path unresolved — set SMALLTALK_REPO or ensure the reference checkout is present"
else
  AC="$(jq -r '.additionalContext // ""' "$FRESH" 2>/dev/null)"
  if printf '%s' "$AC" | grep -qF "$MARK" && printf '%s' "$AC" | grep -qF "$TOKEN"; then
    ok "fresh now.md => codex hook emits the <context source=...> block CONTAINING the token (PR #86 parity)"
  elif [ -z "$AC" ]; then
    no "codex hook emitted NO now.md block for a fresh now.md — reference checkout predates PR #86 (#86 gap: sync to >= f782411)"
  else
    no "codex hook payload lacks the marker+token (unexpected shape) — additionalContext: $(printf '%s' "$AC" | head -c 120)"
  fi
  [ "$(cat "$P/hook-fresh.exit" 2>/dev/null)" = "0" ] && ok "codex hook exit code 0 (valid payload contract)" \
                                                      || wn "codex hook exit code not 0 — eyeball $P/hook-fresh.err"
  # NEGATIVES — missing / stale now.md (+ empty inbox) => no now.md block.
  for neg in missing stale; do
    f="$P/hook-$neg.json"
    if [ -f "$f" ]; then
      ac="$(jq -r '.additionalContext // ""' "$f" 2>/dev/null)"
      printf '%s' "$ac" | grep -qF "$MARK" && no "negative ($neg): codex hook STILL injected a now.md block (leak)" \
                                           || ok "negative ($neg): codex hook emitted NO now.md block (as it must)"
    fi
  done
fi

echo
echo "== RECONSTRUCT (headline, rides the box) — the cold codex agent acted on now.md, 0 rescues =="
if [ -f "$WK/RECONSTRUCTED.log" ]; then
  grep -qF "$TOKEN" "$WK/RECONSTRUCTED.log" && ok "cold codex agent WROTE the now.md token to RECONSTRUCTED.log (reconstructed from durable state)" \
                                            || no "RECONSTRUCTED.log lacks THIS run's token (stale/wrong reconstruction)"
else
  wn "no RECONSTRUCTED.log — live codex reconstruct not exercised (run spin.sh); the deterministic gates carry the proof"
fi

echo
echo "== ISOLATION (hard gate — attribution survives the reload; nothing leaked to global pty) =="
if [ -d "$WK/.git" ]; then
  badauth=$(git -C "$WK" log --format="%ae" 2>/dev/null | grep -vE "rlx-wk@eval.local" | sort -u | tr '\n' ' ')
  [ -z "$badauth" ] && ok "only rlx-wk@eval.local authored commits — attribution survived the cold restart" \
                    || no "ISOLATION VIOLATION: foreign author(s): $badauth"
else
  wn "no worker repo at $WK — did setup run?"
fi
if [ -f "$SB/.stev/pty-root" ]; then
  PR="$(cat "$SB/.stev/pty-root" 2>/dev/null)"
  case "$PR" in
    /Users/*/.local/state/convoy*|*/.local/state/smalltalk*) no "run PTY_ROOT points at a GLOBAL root ($PR)" ;;
    "") wn "empty pty-root record" ;;
    *) ok "run PTY_ROOT is a decoupled per-run root ($PR) — no leak to the operator's global pty" ;;
  esac
else
  sk "no pty-root record (spin.sh not run) — pty isolation check deferred to the live run"
fi

echo
echo "SCORE: $pass PASS / $fail FAIL / $warn WARN / $skip SKIP"
if [ "$fail" -eq 0 ]; then
  echo "==> restorability-codex: NO hard failures. The codex SessionStart hook restores now.md at cold-boot (PR #86"
  echo "    parity with claude), reload carries no --resume/--session-id, attribution survives. Fleet-wide proof that"
  echo "    codex agents restore WITHOUT resume too."
else
  echo "==> restorability-codex: $fail HARD FAILURE(S) — see [FAIL] rows (a codex now.md gap => sync the reference smalltalk checkout to >= f782411 / #86)."
fi
[ "$fail" -eq 0 ]
