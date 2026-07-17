#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# probe.sh (clean-compose) — DETERMINISTIC, box-free. Composes a real convoy agent INTO the throwaway repo and
# captures the ground truth grade.sh asserts on:
#   1. porcelain.txt   — `git status --porcelain` in the repo AFTER `convoy add` (EMPTY = no pollution = PASS).
#   2. written.txt     — every file convoy created (incl. .git/info/exclude-d + gitignored ones), for context:
#                        which are cleanly excluded vs which LEAK.
#   3. mutation.txt    — a synthetic dirt file is planted then `git status --porcelain` re-checked: it MUST turn
#                        non-empty (proves the porcelain gate has TEETH — not vacuously empty). Stray removed after.
#
# No LLM reasoning is graded — only which files convoy wrote. Isolated convoy net + scoped PTY_ROOT; torn down.
#   ./probe.sh [SANDBOX]
# ─────────────────────────────────────────────────────────────────────────────
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/../../../bin/lib-harness.sh"
SB="${1:-${EVAL_SANDBOX:-/tmp}/cc}"
[ -d "$SB/repo/.git" ] || { echo "== sandbox absent — materializing =="; "$HERE/setup-sandbox.sh" "$SB" >/dev/null; }
repo="$SB/repo"; NET="$SB/net"; P="$SB/.probe"; rm -rf "$P"; mkdir -p "$P"
id="ccw"   # clean-compose worker (short — pty socket path limit)

if ! command -v convoy >/dev/null 2>&1; then
  echo "SKIP: convoy not on PATH — clean-compose needs it" >&2
  printf 'CONVOY-MISSING\n' > "$P/porcelain.txt"; exit 0
fi

printf '# clean-compose worker %s\nYou are %s, a test worker.\n' "$id" "$id" > "$P/persona.md"
export ST_ROOT="$NET"; export PTY_ROOT="$NET/pty"    # isolate: session lands in the run net, never the global pty

# Guaranteed teardown of the isolated net on ANY exit (crash, ctrl-c, normal) — this probe leaves nothing up.
trap 'stev_convoy_teardown "$NET" >/dev/null 2>&1 || true' EXIT INT TERM

echo "== 1/3  convoy init isolated net + convoy add the agent INTO the repo =="
# Record WHICH convoy this ran against — the .git/info/exclude coverage is convoy-version-dependent (pre-#53
# leaks pty.toml), so pin the version for reproducibility. Best-effort: --version + the convoy checkout's git SHA.
{ convoy --version 2>&1 | head -1
  cvb="$(command -v convoy 2>/dev/null)"; cvr="$(readlink -f "$cvb" 2>/dev/null || realpath "$cvb" 2>/dev/null || echo "$cvb")"
  git -C "$(dirname "$cvr")/.." rev-parse --short HEAD 2>/dev/null | sed 's/^/convoy_git_sha=/'
} > "$P/convoy-version.txt" 2>/dev/null || true
stev_convoy_init "$NET" >/dev/null 2>&1 || true
convoy add worker --identity "$id" --network "$NET" --dir "$repo" --persona "$P/persona.md" --harness claude >"$P/add.out" 2>&1
echo "   add rc=$? (see $P/add.out)"

echo "== 2/3  capture the repo state convoy left behind =="
# THE gate: porcelain must be EMPTY (no tracked/untracked pollution). Ignored (!!) files don't count against it.
( cd "$repo" && git status --porcelain ) > "$P/porcelain.txt"
# Context: everything convoy created, incl. excluded/ignored, so grade.sh can name what leaks vs what is excluded.
( cd "$repo" && git status --porcelain --ignored ) > "$P/written.txt"
echo "   porcelain (leak state):"; sed 's/^/     /' "$P/porcelain.txt" | head -20; [ -s "$P/porcelain.txt" ] || echo "     (empty — clean)"

echo "== 3/3  MUTATION check — plant synthetic dirt; porcelain MUST detect it (gate has teeth) =="
stray="$repo/.clean-compose-mutation-probe"
: > "$stray"
if [ -n "$( cd "$repo" && git status --porcelain -- .clean-compose-mutation-probe )" ]; then
  printf 'mutation_detected=yes\n' > "$P/mutation.txt"
  echo "   planted dirt IS detected by git status --porcelain (gate is non-vacuous)"
else
  printf 'mutation_detected=no\n' > "$P/mutation.txt"
  echo "   WARNING: planted dirt NOT detected — the porcelain gate would be vacuous"
fi
rm -f "$stray"

echo "== probe artifacts in $P/ =="; ls -1 "$P" | sed 's/^/     /'
echo "GRADE:  $HERE/grade.sh \"$SB\""
