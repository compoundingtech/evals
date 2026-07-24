#!/usr/bin/env bash
# hook-integrity WITNESS — a PARALLEL SessionStart hook, added alongside the REAL smalltalk session-start.sh in
# each leg (see setup.sh). It records the payload session-start.sh injects (context/now.md, verbatim) to a
# deterministic, judge-reachable path, so a HELD-OUT judge can prove the SessionStart hook FIRED from GROUND TRUTH
# — a hook side-effect the model cannot forge — with ZERO dependence on model behavior.
#
# Why this exists: the token also lives in now.md, and a claude 2.1.x agent told to "act on your durable working
# state" reaches now.md via `st context read` (a NON-hook path) — so asserting on the agent's OUTPUT (HOOK_OK.txt)
# is defeated. This witness is written ONLY by the hook itself: it fires iff SessionStart fires (iff the real hook
# fires), and `--settings disableAllHooks` co-suppresses it on the OFF leg → no witness there. The real
# session-start.sh stays UNMODIFIED (still the thing under test); this only OBSERVES its firing.
#
# It writes NOTHING to stdout (a SessionStart hook's stdout is injected into the model context — we must not
# pollute it); the witness is a file side-effect only.
set -u
: "${ST_ROOT:?hook-witness: ST_ROOT unset}" "${ST_AGENT:?hook-witness: ST_AGENT unset}"
cat_dir="$(dirname "$ST_ROOT")"                     # ST_ROOT = $CATALOG/smalltalk  →  $CATALOG
wdir="$cat_dir/hook-witness"; mkdir -p "$wdir"
now="$ST_ROOT/$ST_AGENT/context/now.md"             # the payload session-start.sh injects
[ -f "$now" ] && cp "$now" "$wdir/$ST_AGENT.injected"
exit 0
