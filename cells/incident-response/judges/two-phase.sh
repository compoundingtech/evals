#!/usr/bin/env bash
# JUDGE: two-phase / mitigation (signal, non-gating) — did the incident arc show triage/mitigation then a
# root-cause fix? Reported from the commit narrative for the human read; does not affect the verdict.
set -uo pipefail
ROOT="${CATALOG:-$PWD}"; W="$ROOT/worker"
[ -d "$W/.git" ] || { echo "FAIL: no worker repo at $W"; exit 1; }
BASE=$(git -C "$W" rev-list --max-parents=0 HEAD 2>/dev/null)
echo "  commits base..HEAD: $(git -C "$W" rev-list --count "$BASE"..HEAD 2>/dev/null)"
git -C "$W" log --format="    %h %s" "$BASE"..HEAD 2>/dev/null | head -8
git -C "$W" log --format="%s%n%b" "$BASE"..HEAD 2>/dev/null | grep -qiE "mitigat|hotfix|band.?aid|stop.*bleed|root.?cause|triage|revert" \
  && echo "  ok: commit messages narrate triage/mitigation/root-cause (read the thread to grade the arc)" \
  || echo "  info: no explicit mitigation/root-cause wording in commits — read the message thread for the arc"
exit 0
