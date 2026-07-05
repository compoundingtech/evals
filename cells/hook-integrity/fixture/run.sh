#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# hook-integrity — the SINGLE-COMMAND diagnostic. Clone st-evals, run one command, read a loud
# PASS/FAIL banner that tells you whether your Claude Code SessionStart hook actually FIRES.
#
#   bin/st-evals run hook-integrity          # (preferred — provisions personas, gates on caps)
#   cells/hook-integrity/fixture/run.sh      # (direct)
#
# What it does: generates a fresh secret token; materializes TWO isolated sandboxes with the SAME
# token seeded ONLY into context/now.md (the hook-exclusive channel); launches the probe agent in
# each — one hooks-ON (`st launch claude`), one hooks-OFF (`--no-hooks`); waits for the ON agent to
# write the token to HOOK_OK.txt (proof the SessionStart hook fired + rehydrated); confirms the OFF
# agent could NOT (the negative control); prints the banner; tears both down zero-orphan.
#
# Self-isolating: each leg gets its own scratch bus root ($SB/st-root) that st launch binds into the
# session env — nothing touches your live network. Env: HI_TIMEOUT (default 240s), HI_GRACE (45s).
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/../../../bin/lib-harness.sh"
BASE="${EVAL_SANDBOX:-./.sandbox}/hook-integrity"
case "${1:-}" in */*|/*) BASE="$1" ;; esac   # `st-evals run` forwards the cell NAME as $1 — ignore it; only a path-like arg overrides
SB_ON="$BASE/on"; SB_OFF="$BASE/off"
TIMEOUT="${HI_TIMEOUT:-240}"; GRACE="${HI_GRACE:-45}"

# ONE token for the whole run; both legs seed the SAME string so the grader checks one value.
TOKEN="$(head -c 4 /dev/urandom | od -An -tx1 | tr -d ' \n')"
export HI_TOKEN="$TOKEN"

cleanup() { for sb in "$SB_ON" "$SB_OFF"; do [ -d "$sb/.stev" ] && stev_teardown "$sb" >/dev/null 2>&1 || true; done; }
trap cleanup EXIT INT TERM

echo "== hook-integrity: SessionStart-hook firing diagnostic =="
echo "   token this run: REHYDRATE-$TOKEN   (lives ONLY in each leg's context/now.md)"
echo
echo "== 1/4  materialize both legs (same seeded token; isolated buses) =="
"$HERE/setup-sandbox.sh" "$SB_ON"  >/dev/null
"$HERE/setup-sandbox.sh" "$SB_OFF" >/dev/null
stev_init hook-integrity "$SB_ON"; stev_init hook-integrity "$SB_OFF"
echo "   on:  $SB_ON     off: $SB_OFF"

echo "== 2/4  launch the probe agent in each leg (hooks ON vs --no-hooks) =="
( export ST_ROOT="$SB_ON/st-root";  export COORD_ROOT="$ST_ROOT"; "$HERE/configure-claude-agent.sh" on  "$SB_ON" )
( export ST_ROOT="$SB_OFF/st-root"; export COORD_ROOT="$ST_ROOT"; "$HERE/configure-claude-agent.sh" off "$SB_OFF" )

echo "== 3/4  wait for the hooks-ON agent to receive + write the rehydrate token =="
ON_FILE="$SB_ON/repo/HOOK_OK.txt"; WANT="REHYDRATE-$TOKEN"
t=0; on_ok=false; graced=0
while [ "$t" -lt "$TIMEOUT" ]; do
  if [ -f "$ON_FILE" ] && grep -qF "$WANT" "$ON_FILE" 2>/dev/null; then on_ok=true; fi
  off_tok=no; { [ -f "$SB_OFF/repo/HOOK_OK.txt" ] && grep -qF "$WANT" "$SB_OFF/repo/HOOK_OK.txt" 2>/dev/null; } && off_tok=yes
  printf '   t=%3ds  hooks-ON token: %s   hooks-OFF token(control, want no): %s\n' "$t" "$([ "$on_ok" = true ] && echo YES || echo …)" "$off_tok"
  if [ "$on_ok" = true ]; then
    # ON produced the token; give the OFF leg a short grace to (not) do the same, then stop.
    if [ "$graced" -ge "$GRACE" ]; then break; fi
    graced=$((graced+10))
  fi
  sleep 10; t=$((t+10))
done

echo "== 4/4  grade + banner =="
set +e
"$HERE/grade.sh" "$SB_ON" "$SB_OFF"
rc=$?
set -e
exit "$rc"
