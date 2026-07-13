#!/usr/bin/env bash
# Spin the restorability-CODEX cell via REAL convoy (`--harness codex`, ding-default). THIN twin of
# ../../restorability: one codex worker (rlx-wk, auto, owns its repo). The codex twin's value is the now.md RESTORE
# PARITY — proving the codex SessionStart hook (PR #86) reconstructs now.md at a no-resume cold boot, fleet-wide.
# (The stuck-queue discriminator is a claude CC-input-queue concern and lives only in the claude cell.)
# SELF-ISOLATING: `convoy init`s an isolated net at $SB/net + a decoupled short PTY_ROOT.
#
# Sequence: init net -> seed now.md -> convoy add rlx-wk --harness codex (cold boot #1) -> convoy reload rlx-wk
#   (cold boot #2 = the RESTART; NO --resume/--session-id) -> the codex SessionStart hook injects now.md ->
#   rlx-wk reconstructs + writes RECONSTRUCTED.log.
#   ./spin.sh [SANDBOX]        # sandbox defaults to ${EVAL_SANDBOX:-/tmp}/rlx
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/../../../bin/lib-harness.sh"
SB="${1:-${EVAL_SANDBOX:-/tmp}/rlx}"
NET="$SB/net"; export ST_ROOT="$NET"

[ -f "$SB/now.md.seed" ] || { echo "== sandbox absent — materializing =="; "$HERE/setup-sandbox.sh" "$SB" >/dev/null; }

stev_init "restorability-codex" "$SB"
export PTY_ROOT="$(stev_pty_root "$SB")"

STEV_NET="$NET"
trap 'rc=$?; [ "$rc" = 0 ] || { echo "== spin rc=$rc — tearing down the isolated net ==" >&2; stev_convoy_teardown "$STEV_NET"; stev_teardown "$SB"; }' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

echo "== 1/4  convoy init the isolated network ($NET) =="
stev_convoy_init "$NET"

echo "== 2/4  seed now.md (durable resume-task) into the net =="
mkdir -p "$NET/rlx-wk/context"
cp "$SB/now.md.seed" "$NET/rlx-wk/context/now.md"
echo "   seeded $NET/rlx-wk/context/now.md (token $(tr -d '\r\n' < "$SB/.token"))"

echo "== 3/4  compose persona + convoy add rlx-wk (--harness codex; auto) — cold boot #1 =="
"$HERE/compose-persona.sh" "$SB"
convoy pretrust "$SB/rlx-wk" >/dev/null 2>&1 || true
"$HERE/configure-codex-agent.sh" "$SB"

echo "== 4/4  convoy reload rlx-wk — the RESTART under test (NO --resume/--session-id, fresh transcript) =="
tries=0; while [ "$tries" -lt 20 ]; do
  convoy ls "$NET" 2>/dev/null | grep -q 'rlx-wk' && break
  tries=$((tries+1)); sleep 3
done
RL_RELOAD=1 "$HERE/configure-codex-agent.sh" "$SB"

echo
echo "SPUN (restorability-codex cell, isolated convoy net $NET). members:"; convoy ls "$NET" 2>/dev/null | grep -E 'rlx-wk' || convoy ls "$NET" 2>/dev/null
echo "OBSERVE (ST_ROOT=$NET): seed now.md -> convoy add --harness codex -> convoy reload (no-resume) ->"
echo "  rlx-wk reconstructs from now.md via the codex SessionStart hook (PR #86) -> writes RECONSTRUCTED.log."
echo "GRADE after it settles:  $HERE/grade.sh \"$SB\"   (run probe.sh too for the box-free deterministic gates)"
echo "TEARDOWN after grading:  bin/st-evals teardown \"$SB\"   (or: convoy down \"$NET\" --force; rm -rf \"$SB\")"
