#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# Ground-truth grader for RESTORABILITY. Never trusts self-reports — grades the REAL probe artifacts (box-free
# deterministic core) + the live-run artifacts (the headline that rides the box). The deterministic gates are the
# HARD gates; the live reconstruct/discriminator gates are the headline (WARN if not exercised, FAIL if exercised
# and wrong). Run `probe.sh` (deterministic) and, for the headline, `spin.sh` first.
#
# INTEGRITY (cos-approved framing): the NO-STUCK-QUEUE property is proven STRUCTURALLY (the fresh-session
# corollary — no --resume/--session-id/transcript => no channel) and DEMONSTRATED via a transcript-codeword PROXY.
# It is NOT a seeded CC input-queue (undocumented/version-volatile). This grader says so plainly.
#
#   ./grade.sh [SANDBOX]
# Exit 0 = no hard (deterministic) failures.
# ─────────────────────────────────────────────────────────────────────────────
set -uo pipefail
SB="${1:-${EVAL_SANDBOX:-/tmp}/rl}"
P="$SB/.probe"; WK="$SB/rl-wk"
pass=0; fail=0; warn=0; skip=0
ok(){ echo "  [PASS] $1"; pass=$((pass+1)); }
no(){ echo "  [FAIL] $1"; fail=$((fail+1)); }
wn(){ echo "  [WARN] $1"; warn=$((warn+1)); }
sk(){ echo "  [SKIP] $1"; skip=$((skip+1)); }

[ -d "$P" ] || { echo "no probe artifacts at $P — run probe.sh first"; exit 1; }
TOKEN="$(tr -d '\r\n' < "$SB/.token" 2>/dev/null)"
[ -n "$TOKEN" ] && echo "RECONSTRUCT token this run: $TOKEN" || wn "no \$SB/.token — did setup-sandbox run?"

echo
echo "== NO-RESUME (hard, deterministic) — the reload respawn command carries NO --resume/--session-id =="
if [ -f "$P/reload-cmd.txt" ] && [ -s "$P/reload-cmd.txt" ]; then
  CMD="$(cat "$P/reload-cmd.txt")"
  if echo "$CMD" | grep -qiE -- '--resume|--session-id|--session_id'; then
    no "the stored reload command CARRIES --resume/--session-id (a hidden resume) — $CMD"
  else
    ok "reload command carries NO --resume/--session-id (a genuine cold boot)"
  fi
  echo "$CMD" | grep -qE 'exec (claude|codex)' && ok "reload command is a fresh cold-boot exec (not an attach/resume)" \
                                              || wn "reload command shape unexpected — eyeball: $CMD"
else
  sk "no reload-cmd captured (convoy absent, or probe.sh materialization skipped) — NO-RESUME unproven this run"
fi

echo
echo "== NO-QUEUE-CHANNEL (hard, deterministic) — structural corollary: fresh session => no channel for a stuck queue =="
echo "     [framing] STRUCTURAL proof + transcript PROXY; NOT a seeded CC input-queue (undocumented/version-volatile)."
if [ -f "$P/pty.toml" ]; then
  # The corollary: no --resume, no --session-id, and no pinned prior session-id/transcript to replay from.
  if grep -qiE -- '--resume|--session-id|--session_id' "$P/pty.toml"; then
    no "pty.toml pins a --resume/--session-id — a channel for prior-session state EXISTS (queue could carry)"
  elif grep -qiE '\.claude-session-id|resume.*=.*true|prior.transcript' "$P/pty.toml"; then
    wn "pty.toml references a session-id/transcript pin — eyeball whether reload would replay it"
  else
    ok "reload boots a fresh session (no --resume/--session-id/transcript pin) => structurally NO channel for a stuck queue to carry"
  fi
else
  sk "no pty.toml captured — NO-QUEUE-CHANNEL corollary unproven this run"
fi

echo
echo "== REHYDRATE-WIRED (hard, deterministic) — SessionStart hook resolvable + now.md non-empty with the token =="
HOOKP="$(cat "$P/hook-path.txt" 2>/dev/null)"
if [ -n "$HOOKP" ] && [ -f "$HOOKP" ]; then ok "claude SessionStart hook resolved + present ($HOOKP)"; \
                                       else no "SessionStart hook NOT resolved ($HOOKP) — reconstruction cannot happen (NAME the blocker)"; fi
if [ -s "$SB/now.md.seed" ] && grep -qF "$TOKEN" "$SB/now.md.seed" 2>/dev/null; then
  ok "now.md is non-empty and carries the RECONSTRUCT token (durable resume-task present)"
else
  no "now.md.seed empty or missing the token — nothing durable to reconstruct FROM (the empty-now.md gap)"
fi

echo
echo "== HOOK-EMITS-BLOCK (hard, deterministic — correction #1 STRONGER) — hook injects the now.md <context> block =="
MARK='<context source="st/context/now.md" agent="rl-wk">'
if [ -f "$P/hook-fresh.txt" ] && [ "$(cat "$P/hook-fresh.txt" 2>/dev/null)" != "HOOK-UNRESOLVED" ]; then
  if grep -qF "$MARK" "$P/hook-fresh.txt" && grep -qF "$TOKEN" "$P/hook-fresh.txt"; then
    ok "fresh now.md => hook emits the <context source=...> block CONTAINING the token"
  else
    no "fresh now.md => hook did NOT emit the marker+token block (reconstruction enabler broken)"
  fi
  [ "$(cat "$P/hook-fresh.exit" 2>/dev/null)" = "2" ] && ok "hook exit code 2 (the asyncRewake system-reminder contract)" \
                                                      || wn "hook exit code not 2 (claude may not surface it as a reminder)"
  # NEGATIVES — prove the gaps.
  if [ -f "$P/hook-missing.txt" ]; then
    grep -qF '<context' "$P/hook-missing.txt" && no "MISSING now.md STILL injected a block (leak) — negative broken" \
                                              || ok "negative: MISSING now.md => NO block (context lost, as it must)"
  fi
  if [ -f "$P/hook-stale.txt" ]; then
    grep -qF '<context' "$P/hook-stale.txt" && no "STALE now.md STILL injected (stale is worse than none) — negative broken" \
                                            || ok "negative: STALE now.md => NO block (freshness gate holds)"
  fi
else
  sk "hook not run (unresolved) — HOOK-EMITS-BLOCK unproven this run"
fi

echo
echo "== RECONSTRUCT (headline, rides the box) — the cold agent acted on now.md, 0 rescues =="
if [ -f "$WK/RECONSTRUCTED.log" ]; then
  if grep -qF "$TOKEN" "$WK/RECONSTRUCTED.log"; then
    ok "cold-booted agent WROTE the now.md token to RECONSTRUCTED.log — reconstructed from durable state alone"
  else
    no "RECONSTRUCTED.log exists but lacks THIS run's token (stale/wrong reconstruction)"
  fi
else
  wn "no RECONSTRUCTED.log — live reconstruct not exercised (run spin.sh); the deterministic gates above carry the proof"
fi

echo
echo "== DISCRIMINATOR (headline, rides the box, gated) — --resume RECALLS the codeword; reload SHEDS it =="
echo "     [framing] a DOCUMENTED PROXY on the restore-channel property — NOT the real CC input-queue (not seeded)."
DL="$SB/.stev/discriminator.log"
if [ -f "$DL" ]; then
  if grep -q '^skip=' "$DL"; then
    sk "discriminator skipped-with-reason ($(grep '^skip=' "$DL" | tail -1)) — CC-version drift; mechanism corollary carries it"
  else
    grep -q '^resume_recalled=yes' "$DL" && ok "the --resume control RECALLED the transcript codeword (detection PROVEN — the control can see stale state)" \
                                         || no "the --resume control did NOT recall the codeword (detection unproven => the gate would be vacuous)"
    grep -q '^reload_recalled=no' "$DL"  && ok "the cold reload did NOT recall the codeword (cold restart SHEDS session state)" \
                                         || no "the cold reload DID recall the codeword (stale state leaked across a no-resume restart!)"
  fi
else
  sk "no discriminator.log — discriminator arm not exercised (run spin.sh); mechanism corollary (NO-QUEUE-CHANNEL) still carries the structural proof"
fi

echo
echo "== ISOLATION (hard gate — attribution survives the reload; nothing leaked to global pty) =="
if [ -d "$WK/.git" ]; then
  badauth=$(git -C "$WK" log --format="%ae" 2>/dev/null | grep -vE "rl-wk@eval.local" | sort -u | tr '\n' ' ')
  [ -z "$badauth" ] && ok "only rl-wk@eval.local authored commits — attribution survived the cold restart" \
                    || no "ISOLATION VIOLATION: foreign author(s): $badauth"
else
  wn "no worker repo at $WK — did setup run?"
fi
if [ -f "$SB/.stev/pty-root" ]; then
  PR="$(cat "$SB/.stev/pty-root" 2>/dev/null)"
  case "$PR" in
    /Users/*/.local/state/convoy*|*/.local/state/smalltalk*) no "run PTY_ROOT points at a GLOBAL root ($PR) — isolation breach risk" ;;
    "") wn "empty pty-root record" ;;
    *) ok "run PTY_ROOT is a decoupled per-run root ($PR) — sessions cannot leak to the operator's global pty" ;;
  esac
else
  sk "no pty-root record (spin.sh not run) — pty isolation check deferred to the live run"
fi

echo
echo "SCORE: $pass PASS / $fail FAIL / $warn WARN / $skip SKIP"
if [ "$fail" -eq 0 ]; then
  echo "==> restorability: NO hard failures. Deterministic core proven — reload carries no --resume/--session-id,"
  echo "    the SessionStart hook reconstructs now.md, and (structurally) no stuck queue can carry. The live headline"
  echo "    (RECONSTRUCT + DISCRIMINATOR) + the codex twin complete the mandate proof: agents do not use resume AND do"
  echo "    not need it. NOTE: the queue property is STRUCTURAL + a transcript PROXY, NOT a seeded CC input-queue."
else
  echo "==> restorability: $fail HARD FAILURE(S) — see [FAIL] rows."
fi
[ "$fail" -eq 0 ]
