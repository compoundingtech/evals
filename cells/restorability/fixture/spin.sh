#!/usr/bin/env bash
# Spin the restorability cell via REAL convoy (`convoy add`, ding-default) — THIN: it REUSES convoy doctor CHECK
# 4's convoy-reload + SessionStart reconstruct mechanism; it does not re-implement it. One worker (rl-wk, auto,
# owns its repo). SELF-ISOLATING: `convoy init`s an isolated net at $SB/net and a decoupled short PTY_ROOT, so the
# live convoy is never touched.
#
# Sequence:
#   init isolated net -> seed now.md (durable resume-task) -> convoy add rl-wk (cold boot #1) -> convoy reload
#   rl-wk (cold boot #2 = the RESTART under test; NO --resume/--session-id) -> the SessionStart hook injects now.md
#   -> rl-wk reconstructs + writes RECONSTRUCTED.log -> (background) the gated DISCRIMINATOR arm.
# Both the add and the reload are no-resume cold boots (that is the thesis); the reload is the explicit restart.
#   ./spin.sh [SANDBOX]        # sandbox defaults to ${EVAL_SANDBOX:-/tmp}/rl
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/../../../bin/lib-harness.sh"
SB="${1:-${EVAL_SANDBOX:-/tmp}/rl}"
NET="$SB/net"; export ST_ROOT="$NET"

[ -f "$SB/now.md.seed" ] || { echo "== sandbox absent — materializing =="; "$HERE/setup-sandbox.sh" "$SB" >/dev/null; }

stev_init "restorability" "$SB"
export PTY_ROOT="$(stev_pty_root "$SB")"   # decoupled short root — every session lands here, never the global pty

STEV_NET="$NET"
trap 'rc=$?; [ "$rc" = 0 ] || { echo "== spin rc=$rc — tearing down the isolated net ==" >&2; stev_convoy_teardown "$STEV_NET"; stev_teardown "$SB"; }' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

echo "== 1/5  convoy init the isolated network ($NET) =="
stev_convoy_init "$NET"

echo "== 2/5  seed now.md (the durable resume-task) into the net so any no-resume cold boot reconstructs it =="
mkdir -p "$NET/rl-wk/context"
cp "$SB/now.md.seed" "$NET/rl-wk/context/now.md"
echo "   seeded $NET/rl-wk/context/now.md (token $(tr -d '\r\n' < "$SB/.token"))"

echo "== 3/5  compose persona + convoy add rl-wk (auto; owns its repo) — cold boot #1 =="
"$HERE/compose-persona.sh" "$SB"
convoy pretrust "$SB/rl-wk" >/dev/null 2>&1 || true
"$HERE/configure-claude-agent.sh" "$SB"

echo "== 4/5  convoy reload rl-wk — the RESTART under test (NO --resume/--session-id, fresh transcript) =="
# Give the first boot a moment to settle so the reload is a clean, observable restart event.
tries=0; while [ "$tries" -lt 20 ]; do
  convoy ls "$NET" 2>/dev/null | grep -q 'rl-wk' && break
  tries=$((tries+1)); sleep 3
done
RL_RELOAD=1 "$HERE/configure-claude-agent.sh" "$SB"

echo "== 5/5  arm the gated DISCRIMINATOR arm (background: transcript-codeword proxy; skips-with-reason if not establishable) =="
mkdir -p "$SB/.stev"
nohup "$HERE/discriminator.sh" "$SB" >> "$SB/.stev/discriminator.out" 2>&1 &
disown 2>/dev/null || true
echo "   discriminator backgrounded (pid $!); log: $SB/.stev/discriminator.log"

echo
echo "SPUN (restorability cell, isolated convoy net $NET). members:"; convoy ls "$NET" 2>/dev/null | grep -E 'rl-wk' || convoy ls "$NET" 2>/dev/null
echo "OBSERVE (ST_ROOT=$NET): seed now.md -> convoy add (cold boot) -> convoy reload (no-resume restart) ->"
echo "  rl-wk reconstructs from now.md via the SessionStart hook -> writes RECONSTRUCTED.log with the token."
echo "GRADE after it settles:  $HERE/grade.sh \"$SB\"   (run probe.sh too for the box-free deterministic gates)"
echo "TEARDOWN after grading:  bin/st-evals teardown \"$SB\"   (or: convoy down \"$NET\" --force; rm -rf \"$SB\")"
