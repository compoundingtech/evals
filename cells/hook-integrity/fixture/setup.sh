#!/usr/bin/env bash
# Materialize BOTH hook-integrity legs, as the eval's `run { step "setup" }` (BEFORE the team boots). Renders the
# REAL rendered SessionStart hook into two identical workspaces (repo-on, repo-off) and seeds the SAME per-run
# secret token into each leg's context/now.md (the hook-exclusive channel). The ONLY difference between the legs at
# boot is whether claude FIRES the hook — the control boots with `--no-hooks`. So a token that lands only in the ON
# leg is attributable to the hook actually firing (execution), not merely being configured.
set -euo pipefail
SB="${CATALOG:?CATALOG must be set — st2 eval provides it to run steps}"
cd "$SB"

# One fresh token for this run — reachable ONLY via now.md (not in persona, repo, or the kick).
TOKEN="$(head -c 4 /dev/urandom | od -An -tx1 | tr -d ' \n')"
printf 'REHYDRATE-%s\n' "$TOKEN" > "$SB/want.txt"     # ground truth for the judges (not an agent input)

seed_leg() {   # <leg-workspace> <identity>
  local ws="$1" id="$2"
  mkdir -p "$ws"
  git -C "$ws" init -q -b main
  echo "# probe repo ($id)" > "$ws/README.md"
  git -C "$ws" add -A && git -C "$ws" -c user.name="eval" -c user.email="eval@local" commit -q -m "init"
  # render the REAL overlay incl. the SessionStart hook into the leg workspace (identical config for both legs)
  st2 render-agent --identity "$id" --dir "$SB/$ws" --persona "$SB/persona.md" --harness claude "$SB/cat-$id"
  # seed now.md at the hook's read path: $ST_ROOT/$id/context/now.md  (ST_ROOT=$CATALOG/smalltalk)
  local nowdir="$SB/smalltalk/$id/context"; mkdir -p "$nowdir"
  sed "s/__TOKEN__/$TOKEN/g" "$SB/now.md.tmpl" > "$nowdir/now.md"
}
seed_leg repo-on  hi.on
seed_leg repo-off hi.off

grep -q session-start "$SB/repo-on/.claude/settings.local.json" && grep -q session-start "$SB/repo-off/.claude/settings.local.json" \
  || { echo "FATAL: the SessionStart hook was not rendered into both legs (is 'st' on PATH?)"; exit 1; }
echo "both legs seeded with REHYDRATE-$TOKEN; the SessionStart hook is configured IDENTICALLY in both — the control only differs by --no-hooks"
