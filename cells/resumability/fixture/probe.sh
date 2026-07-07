#!/usr/bin/env bash
# Probe `st launch`'s resume-vs-fresh behavior via --dry-run — DETERMINISTIC (no agent launched, no box needed).
# Captures the generated claude command for the DEFAULT (resume) and --fresh arms + the pinned session-id
# before/after, so grade.sh can assert the resume mechanism the reboot migration relies on.
#   ./probe.sh [SANDBOX]
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SB="${1:-${EVAL_SANDBOX:-./.sandbox}/resumability}"
[ -f "$SB/work/.claude-session-id" ] || { echo "== sandbox absent — materializing =="; "$HERE/setup-sandbox.sh" "$SB"; }
d="$SB/work"; STR="$SB/root"; mkdir -p "$STR" "$SB/.probe"

cp "$d/.claude-session-id" "$SB/.probe/sid-before.txt"            # the pinned session-id going in

echo "== DEFAULT launch (dry-run) — should RESUME the pinned session =="
( cd "$d" && ST_ROOT="$STR" st launch claude --identity resum-agent --dry-run 2>&1 ) > "$SB/.probe/default.txt"

echo "== --fresh launch (dry-run) — should OMIT --resume (the deliberate opt-out) =="
( cd "$d" && ST_ROOT="$STR" st launch claude --identity resum-agent --fresh --dry-run 2>&1 ) > "$SB/.probe/fresh.txt"

cp "$d/.claude-session-id" "$SB/.probe/sid-after.txt"            # must be UNCHANGED (--fresh is one-off)

echo "PROBED -> $SB/.probe/  (default.txt, fresh.txt, sid-before/after.txt)"
echo "GRADE:  $HERE/grade.sh \"$SB\""
