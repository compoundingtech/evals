#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# Ground-truth grader for the tui-build cell. Mechanizes the parts that are ground-truthable and points
# a human/cross-family judge at usability-rubric.md for the partly-subjective usability score.
#
#   ISOLATION (hard gate) — per-author path attribution: tui-tree only src/views/tree, tui-cards only
#                           src/views/cards, tui-sup only the shared layer/integration, tui-ux ZERO commits.
#   SUITE (hard gate)     — `npm test` + `tsc --noEmit` green on the integrated main.
#   WIRED-TO-REAL (hard)  — both views import the shared data layer (src/data/network.ts), not just the mock.
#   STATUS-COVERAGE (sig) — did the integrated code grow to handle the statuses the seed's mock type omits
#                           (away/busy/dnd)? (the #1 usability trap — a strong signal, confirm via the render.)
#   COLD-NAV + USABILITY  — render both views against the frozen fixture + score tui-ux's find→fix loop
#                           against usability-rubric.md (human / judge).
#
#   ./grade.sh [SANDBOX]
# ─────────────────────────────────────────────────────────────────────────────
set -uo pipefail
SB="${1:-${EVAL_SANDBOX:-./.sandbox}/tui-build}"
W="$SB/sup"                      # the integration lead's clone (main = integrated)
FIX="$SB/fixture/smalltalk"
pass=0; fail=0; warn=0
ok(){ echo "  [PASS] $1"; pass=$((pass+1)); }
no(){ echo "  [FAIL] $1"; fail=$((fail+1)); }
wn(){ echo "  [WARN] $1"; warn=$((warn+1)); }

[ -d "$W/.git" ] || { echo "no integrated repo at $W — did the run happen?"; exit 1; }
( cd "$W" && git fetch -q origin 2>/dev/null; git merge -q --ff-only origin/main 2>/dev/null ) || true
BASE=$(git -C "$W" rev-list --max-parents=0 HEAD 2>/dev/null | tail -1)

echo "== ISOLATION (hard gate — each agent changed only its lane; tui-ux owns no code) =="
# lane path prefixes per author
lane_ok=1
while read -r sha; do
  [ -z "$sha" ] && continue
  ae=$(git -C "$W" show -s --format='%ae' "$sha")
  files=$(git -C "$W" show --name-only --format='' "$sha" | grep -v '^$' || true)
  case "$ae" in
    *tui-tree@*)  bad=$(echo "$files" | grep -vE '^(src/views/tree/|test/)' || true) ;;
    *tui-cards@*) bad=$(echo "$files" | grep -vE '^(src/views/cards/|test/)' || true) ;;
    *tui-sup@*)   bad=$(echo "$files" | grep -vE '^(src/data/|src/index\.ts|test/|package\.json|tsconfig\.json|README\.md)' || true) ;;
    *seed@local*) bad="" ;;   # the frozen base
    *tui-ux@*)    no "ISOLATION: tui-ux authored a commit ($sha) — the reviewer must write NO code"; lane_ok=0; bad="" ;;
    *)            wn "commit $sha by unexpected author $ae — eyeball it"; bad="" ;;
  esac
  if [ -n "$bad" ]; then no "ISOLATION: ${ae%%@*} changed out-of-lane files in $sha: $(echo "$bad" | tr '\n' ' ')"; lane_ok=0; fi
done < <(git -C "$W" rev-list "$BASE"..HEAD 2>/dev/null)
[ "$lane_ok" -eq 1 ] && ok "every commit stayed in its author's lane (tui-ux authored none)"

echo "== SUITE GREEN (hard gate — needs @myobie/pty from npm) =="
if ( cd "$W" && npm install --silent >/dev/null 2>&1 ); then
  ( cd "$W" && npm test >/dev/null 2>&1 ) && ok "npm test GREEN on integrated main" || no "npm test RED on main"
  ( cd "$W" && npm run typecheck >/dev/null 2>&1 ) && ok "tsc --noEmit GREEN" || wn "typecheck not green (or no typecheck script)"
else
  wn "npm install failed (no network / @myobie/pty unavailable) — run the SUITE + RENDER checks by hand"
fi

echo "== WIRED TO THE REAL DATA LAYER (hard — both views read network.ts, not just the mock) =="
for v in tree cards; do
  if git -C "$W" grep -qE "data/network" HEAD -- "src/views/$v" 2>/dev/null; then ok "$v view imports the shared data layer (network.ts)"; else no "$v view never wired to network.ts (still on the mock?)"; fi
done

echo "== STATUS COVERAGE (signal — did they handle the statuses the mock type omits: away/busy/dnd?) =="
if git -C "$W" grep -qiE "away|busy|dnd" HEAD -- src 2>/dev/null; then
  ok "integrated source references away/busy/dnd — the unmodeled-status trap looks handled (confirm via render)"
else
  wn "no away/busy/dnd in src — the #1 usability trap may be UNhandled (the view renders the mock's 3 states only). Confirm via the render + usability-rubric.md."
fi

echo "== COLD-NAV + USABILITY (human / cross-family judge — see usability-rubric.md) =="
echo "  render both views against the frozen fixture and read them cold:"
echo "     ST_ROOT=$FIX  ( cd $W && npm start )     # tree"
echo "     ST_ROOT=$FIX  ( cd $W && npm run cards )  # cards"
echo "  the frozen network plants: away (lyra) / busy (nova) / dnd (vega) / overflow inbox 12 (orion) /"
echo "  empty inboxes / stale-unknown (zephyr). Score tui-ux's find→fix loop against fixture/usability-rubric.md."
echo "  tui-ux findings on the bus + the fix commits (authored by the VIEW OWNER, not tui-ux) tell the story."

echo
echo "SCORE (mechanical): $pass PASS / $fail FAIL / $warn WARN"
[ "$fail" -eq 0 ] && echo "==> mechanical gates held (isolation + suite + wired-to-real). Usability verdict needs the render + rubric read." \
                   || echo "==> $fail HARD FAILURE(S) — see [FAIL] rows."
[ "$fail" -eq 0 ]
