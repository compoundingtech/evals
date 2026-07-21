#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# TEMPLATE — copy to cells/<name>/fixture/grade.sh and adapt.
# The HELD-OUT judge (the team never sees this). Grade REAL STATE, never a self-report:
#   • the message bus — inbox/archive frontmatter (`from:`, `in-reply-to:`) for threading + who-said-what
#   • git attribution — `git log --format='%ae'` per repo (the isolation gate)
#   • convoy's --json event log — host `up` / `respawn` events (convoy cells)
#   • sandbox artifacts — a token/file the correct result must produce
# It must accept ANY correct solution (not one canonical diff) AND still fail a deliberately-wrong mock.
# THE DISCRIMINATOR: the one held-out check a unit-test edit can't fake — make it loud.
#   ./grade.sh [SANDBOX]
# ─────────────────────────────────────────────────────────────────────────────
set -uo pipefail
SB="${1:-${EVAL_SANDBOX:-./.sandbox}/TODO_name}"
NET="$SB/st-root"                                  # the isolated bus root spin.sh created
pass=0; fail=0; warn=0
ok(){ echo "  [PASS] $1"; pass=$((pass+1)); }
no(){ echo "  [FAIL] $1"; fail=$((fail+1)); }
wn(){ echo "  [WARN] $1"; warn=$((warn+1)); }

[ -d "$NET" ] || { echo "no bus at $NET — did spin run?"; exit 1; }

echo "== ISOLATION (hard gate — only the owner authored its repo) =="
# TODO: set OWNER to the seat that owns the worker repo; the gate fails on any foreign author.
OWNER="${WORKER_ID:-TODO-worker}"
badauth="$(git -C "$SB/worker" log --format='%ae' 2>/dev/null | grep -vE "$OWNER@eval.local" | sort -u | tr '\n' ' ')"
[ -z "$badauth" ] && ok "only $OWNER authored the worker repo" || no "foreign author(s) touched the worker repo: $badauth"

echo "== TASK SUCCESS (the ground-truth artifact is correct) =="
# TODO: assert the ACTUAL result — accept any correct form, e.g. grep for a canonical MIT header, a value,
# a passing held-out test replayed against the base commit. Do NOT assert one exact diff.
if TODO_check_the_real_artifact 2>/dev/null; then ok "TODO(what correct looks like)"; else no "TODO(what wrong looks like)"; fi

echo "== COORDINATION (held-out — the loop closed ON THE THREAD, visible on the bus) =="
# TODO: prove the collaboration flowed through messages — e.g. a reply in the requester's inbox whose
# `in-reply-to:` == the seeded kick (threaded reply, not a fresh send), carrying the answer token.
kickfn="$(cat "$SB/.stev/kick-filename" 2>/dev/null)"
reply="$(grep -lRE '^from:[[:space:]]*TODO-supervisor([[:space:]]|$)' "$NET/eval-runner/inbox" "$NET/eval-runner/archive" 2>/dev/null | head -1)"
if [ -z "$reply" ]; then no "no reply reached the requester — the loop did not close"
else
  irt="$(grep -E '^in-reply-to:' "$reply" 2>/dev/null | head -1 | sed 's/^in-reply-to:[[:space:]]*//')"
  { [ -n "$kickfn" ] && [ "$irt" = "$kickfn" ]; } && ok "threaded reply (in-reply-to == the kick) — coordination was visible on the bus" \
    || wn "reply present but not threaded to the kick ($irt vs $kickfn) — confirm the thread"
fi

echo
echo "SCORE (mechanical): $pass PASS / $fail FAIL / $warn WARN"
echo "AUTONOMY (headline): rescues/nudges after the single kick — target 0 (read the run log)."
[ "$fail" -eq 0 ] && echo "==> TODO(name): PASS — TODO(one-line what passing means)." \
                   || echo "==> TODO(name): FAIL — see [FAIL] rows above."
[ "$fail" -eq 0 ]     # <-- the machine verdict: exit 0 = PASS, nonzero = FAIL
