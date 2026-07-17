#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# probe.sh (convoy-init-narration) — DETERMINISTIC, box-free, no LLM. Proves the redesign's NARRATED `convoy init`
# (redesign #5, convoy #60/072808a): the default run tells the user what's happening step-by-step in plain
# language, `--quiet` is silent, and `--json` emits a one-line machine summary. A LIGHT narration-presence check —
# it asserts the key steps are narrated + the mode contrasts, not the exact prose (which the tool owner may tweak).
# Captures:
#   def.out   — default `convoy init <path>` stdout (the step narration)
#   quiet.out — `convoy init --quiet <path>` stdout (must be EMPTY)
#   json.out  — `convoy init --json <path>` stdout (one-line {network,dir,stRoot,ptyRoot,worktrees})
#
# Isolated PATHS (used as-is, never the real state home); torn down; never touches the live convoy.
#   ./probe.sh [SANDBOX]
# ─────────────────────────────────────────────────────────────────────────────
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/../../../bin/lib-harness.sh"
SB="${1:-${EVAL_SANDBOX:-/tmp}/cin}"
rm -rf "$SB"; mkdir -p "$SB"
P="$SB/.probe"; mkdir -p "$P"

if ! command -v convoy >/dev/null 2>&1; then
  echo "SKIP: convoy not on PATH" >&2; printf 'CONVOY-MISSING\n' > "$P/shape.txt"; exit 0
fi
{ convoy --version 2>&1 | head -1
  cvb="$(command -v convoy 2>/dev/null)"; cvr="$(readlink -f "$cvb" 2>/dev/null || realpath "$cvb" 2>/dev/null || echo "$cvb")"
  git -C "$(dirname "$cvr")/.." rev-parse --short HEAD 2>/dev/null | sed 's/^/convoy_git_sha=/'
  git -C "$(dirname "$cvr")/.." diff --quiet 2>/dev/null && echo "convoy_worktree=clean" || echo "convoy_worktree=DIRTY (ahead of committed sha)"
} > "$P/convoy-version.txt" 2>/dev/null || true

echo "== run convoy init in DEFAULT / --quiet / --json modes (isolated paths) =="
# stdout ONLY (the narration/summary is on stdout; --quiet silences stdout).
convoy init      "$SB/nd" > "$P/def.out"   2>"$P/def.err"
convoy init --quiet "$SB/nq" > "$P/quiet.out" 2>"$P/quiet.err"
convoy init --json  "$SB/nj" > "$P/json.out"  2>"$P/json.err"

echo "== capture the narration shape =="
def="$P/def.out"; jl="$P/json.out"
{
  echo "def_lines=$(grep -c . "$def")"
  # Key steps narrated in plain language (tolerant substrings, not exact prose):
  grep -qiE 'set up your convoy network|Creating the network structure|network structure' "$def" && echo "narr_structure=yes" || echo "narr_structure=no"
  grep -qiE 'convoy\.toml|network config' "$def" && echo "narr_config=yes" || echo "narr_config=no"
  grep -qiE 'is ready|Network .* ready' "$def" && echo "narr_ready=yes" || echo "narr_ready=no"
  grep -qiE 'convoy doctor' "$def" && echo "narr_doctor_next=yes" || echo "narr_doctor_next=no"
  # --quiet: zero stdout lines.
  echo "quiet_lines=$(grep -c . "$P/quiet.out")"
  # --json: exactly one line, valid JSON, with all 5 keys.
  echo "json_lines=$(grep -c . "$jl")"
  if command -v jq >/dev/null 2>&1 && jq -e . "$jl" >/dev/null 2>&1; then
    miss=""; for k in network dir stRoot ptyRoot worktrees; do jq -e "has(\"$k\")" "$jl" >/dev/null 2>&1 || miss="$miss $k"; done
    [ -z "$miss" ] && echo "json_keys_ok=yes" || echo "json_keys_ok=no (missing:$miss)"
  else
    # jq absent: fall back to a grep for each key name in the one-line JSON.
    miss=""; for k in network dir stRoot ptyRoot worktrees; do grep -q "\"$k\"" "$jl" || miss="$miss $k"; done
    [ -z "$miss" ] && echo "json_keys_ok=yes" || echo "json_keys_ok=no (missing:$miss)"
  fi
  # SELF-TEST (mutation-validity): a phrase that is NOT in the narration must read absent (grep genuinely discriminates).
  grep -qiF 'this exact phrase is not in convoy narration xyzzy' "$def" && echo "selftest_absent=no" || echo "selftest_absent=yes"
} > "$P/shape.txt"
sed 's/^/     /' "$P/shape.txt"

echo "== teardown the isolated nets =="
for n in nd nq nj; do stev_convoy_teardown "$SB/$n" >/dev/null 2>&1 || true; done

echo "== probe artifacts in $P/ =="; ls -1 "$P" | sed 's/^/     /'
echo "GRADE:  $HERE/grade.sh \"$SB\""
