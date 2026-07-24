#!/usr/bin/env bash
# Materialize BOTH hook-integrity legs, as the eval's `run "setup"` (BEFORE the team boots). Renders the REAL
# SessionStart hook (smalltalk session-start.sh) into two identical workspaces (repo-on, repo-off), seeds the SAME
# per-run secret token into each leg's context/now.md, and adds a PARALLEL SessionStart WITNESS hook (hook-witness.sh)
# that records now.md to $CATALOG/hook-witness/<id>.injected when SessionStart fires — a deterministic, judge-reachable,
# model-proof side-effect. The ONLY difference between the legs at boot is whether claude FIRES the hooks — the
# control boots with `--settings disableAllHooks` (co-suppresses BOTH the real hook and the witness). A witness that
# appears only on the ON leg is attributable to the hook actually firing (execution), not merely being configured.
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
add_witness() {   # <leg-workspace> — add the parallel SessionStart witness alongside the real session-start.sh
  local s="$SB/$1/.claude/settings.local.json"
  jq --arg cmd "bash $SB/hook-witness.sh" \
     '.hooks.SessionStart[0].hooks += [{"type":"command","command":$cmd}]' "$s" > "$s.tmp" && mv "$s.tmp" "$s"
}

seed_leg repo-on  hi.on
seed_leg repo-off hi.off
add_witness repo-on
add_witness repo-off

# Both legs must have BOTH the real hook AND the witness configured identically (the ONLY runtime difference is
# disableAllHooks on the OFF leg). Verify from ground truth so a render/jq regression can't hollow-pass.
for leg in repo-on repo-off; do
  s="$SB/$leg/.claude/settings.local.json"
  grep -q session-start "$s" || { echo "FATAL: session-start.sh not rendered into $leg (is 'st' on PATH?)"; exit 1; }
  grep -q hook-witness.sh "$s" || { echo "FATAL: the witness hook was not added to $leg"; exit 1; }
done
echo "both legs seeded with REHYDRATE-$TOKEN; the real SessionStart hook + the witness are configured IDENTICALLY in both — the control differs ONLY by --settings disableAllHooks"
