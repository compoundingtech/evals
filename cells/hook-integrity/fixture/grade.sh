#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# hook-integrity grader — assert (from GROUND TRUTH) that the SessionStart hook FIRES, and print a
# LOUD PASS/FAIL banner a solo reader can act on. Never trusts self-reports; reads the files.
#
#   HARD gate 1 (hooks ON)  — repo/HOOK_OK.txt exists AND contains exactly `REHYDRATE-<token>`.
#                             The token lived ONLY in context/now.md (hook-exclusive), so its
#                             presence PROVES the SessionStart hook fired + rehydrated.
#   HARD gate 2 (hooks OFF) — repo/HOOK_OK.txt has NO such token (the negative control). A check
#                             that passes with AND without hooks tests nothing; this is the teeth.
#   SOFT — isolation (only hi-agent/seed authored commits) + boot-ritual observation (status/inbox).
#
#   ./grade.sh <SB_ON> <SB_OFF>        # run.sh passes both legs' sandboxes
# Exit 0 = PASS (both hard gates); non-zero = FAIL.
# ─────────────────────────────────────────────────────────────────────────────
set -uo pipefail
SB_ON="${1:?usage: grade.sh <SB_ON> <SB_OFF>}"; SB_OFF="${2:?usage: grade.sh <SB_ON> <SB_OFF>}"
TOKEN="$(cat "$SB_ON/.hi-token" 2>/dev/null || true)"
WANT="REHYDRATE-${TOKEN}"

# color only on a tty and when NO_COLOR is unset
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then G=$'\033[1;32m'; R=$'\033[1;31m'; Y=$'\033[1;33m'; B=$'\033[1m'; X=$'\033[0m'; else G=; R=; Y=; B=; X=; fi
line="════════════════════════════════════════════════════════════════════════"

has_token() { local f="$1/repo/HOOK_OK.txt"; [ -n "$TOKEN" ] && [ -f "$f" ] && grep -qF "$WANT" "$f"; }
foreign_authors() { git -C "$1/repo" log --format='%ae' 2>/dev/null | grep -vE 'hi-agent@eval\.local|seed@local' | sort -u | tr '\n' ' '; }

on_ok=false;  has_token "$SB_ON"  && on_ok=true
off_leak=false; has_token "$SB_OFF" && off_leak=true

echo
if [ -z "$TOKEN" ]; then
  echo "${R}${B}$line${X}"; echo "${R}${B}  ❌  HOOK INTEGRITY: FAIL — no token recorded (setup did not run?)${X}"; echo "${R}${B}$line${X}"; echo
  exit 2
fi

# ── details (always shown, above the banner) ─────────────────────────────────
echo "${B}hook-integrity — SessionStart rehydrate check${X}   (token this run: ${WANT})"
if $on_ok; then echo "  ${G}[PASS]${X} hooks ON  → HOOK_OK.txt contains the rehydrate token (SessionStart fired + injected context/now.md)"
else           echo "  ${R}[FAIL]${X} hooks ON  → HOOK_OK.txt missing or wrong token (repo/HOOK_OK.txt = $(cat "$SB_ON/repo/HOOK_OK.txt" 2>/dev/null | head -1 | cut -c1-40 || echo '<absent>'))"; fi
if $off_leak; then echo "  ${R}[FAIL]${X} hooks OFF → token PRESENT (negative control LEAKED — the check isn't isolating the hook)"
else               echo "  ${G}[PASS]${X} hooks OFF → token absent (control holds: the token is unreachable without the hook)"; fi
fa_on="$(foreign_authors "$SB_ON")"; fa_off="$(foreign_authors "$SB_OFF")"
if [ -z "$fa_on$fa_off" ]; then echo "  ${G}[ok]${X}   isolation — only hi-agent/seed authored commits in both repos"
else                            echo "  ${Y}[warn]${X} isolation — foreign commit author(s): ${fa_on}${fa_off}"; fi

# ── the loud banner (the solo-readable verdict) ──────────────────────────────
echo
if $on_ok && ! $off_leak; then
  echo "${G}${B}$line${X}"
  echo "${G}${B}  ✅  HOOK INTEGRITY: PASS${X}"
  echo "${G}${B}$line${X}"
  echo "  Your Claude Code ${B}SessionStart hook FIRES${X} — it rehydrated context/now.md on launch"
  echo "  (hooks ON delivered the secret token; hooks OFF did not). Boot-ritual + restart-continuity"
  echo "  rehydrate machinery is live on this machine."
  echo "${G}${B}$line${X}"; echo
  exit 0
else
  echo "${R}${B}$line${X}"
  echo "${R}${B}  ❌  HOOK INTEGRITY: FAIL${X}"
  echo "${R}${B}$line${X}"
  if ! $on_ok; then
    echo "  The ${B}SessionStart hook did NOT fire${X} (the silent-hook failure mode)."
    echo "  With hooks wired, the agent never received the rehydrate token, so it never wrote"
    echo "  HOOK_OK.txt. On this machine, Claude Code launched WITHOUT running your SessionStart hook."
    echo "  Check:  1) .claude/settings.local.json exists in the launched repo and has a SessionStart"
    echo "             hook entry;  2) the hook command/path resolves + is executable;  3) the launched"
    echo "             session transcript shows a <context source=\"coord/context/now.md\"> block."
  fi
  if $off_leak; then
    echo "  ${B}Negative control LEAKED${X}: the token appeared even with --no-hooks. The check is not"
    echo "  isolating the hook (the token reached the agent another way) — the result is UNRELIABLE."
    echo "  Investigate before trusting a PASS: the token must live ONLY in context/now.md."
  fi
  echo "${R}${B}$line${X}"; echo
  exit 1
fi
