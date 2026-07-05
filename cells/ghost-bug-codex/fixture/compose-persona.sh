#!/usr/bin/env bash
# Compose a Ghost-bug CODEX-cell agent's persona = debug task-lane + coord boot ritual + BASE
# (dev-practices + known-harness-bugs) + role persona. Codex family -> AGENTS.md.
#   ./compose-persona.sh <sup|fix> [SANDBOX] [REQUESTER]
set -euo pipefail
role="$1"; SB="${2:-${EVAL_SANDBOX:-./.sandbox}/ghost-bug-codex}"; REQUESTER="${3:-eval-runner}"
PZ="${PERSONAS_DIR:?set PERSONAS_DIR to a checkout of github.com/myobie/personas (bin/ensure-personas.sh clones it pinned)}"
WORKER_REPO="$SB/worker"

case "$role" in
  sup) id="gbx-sup"; dir="$SB/sup";       rolefile="$PZ/manager.md" ;;
  fix) id="gbx-fix"; dir="$WORKER_REPO";   rolefile="$PZ/specialist.md" ;;
  *) echo "role must be sup|fix" >&2; exit 1 ;;
esac
out="$dir/AGENTS.md"; mkdir -p "$dir"

if [ "$role" = "sup" ]; then
cat > "$out" <<LANE
# $id — eval SUPERVISOR (Ghost-bug / debug run, full-Codex team)

You are \`$id\` on smalltalk/coord. You **coordinate a debugging task**; you do not do the product work yourself.

**Your task is already in your inbox** — a bug report from \`$REQUESTER\`. Handle it by delegation.

## Hard rules — this is exactly what is being tested
- You own **NO** product repo. The \`labelkit\` library at \`$WORKER_REPO\` is owned by \`gbx-fix\`.
  **Never edit or commit to it.** (You MAY *read* it read-only — \`git -C $WORKER_REPO log/status/show/diff\`,
  and read source/tests — to verify after gbx-fix reports.)
- **All coordination flows through coord** (coord_msg_send / coord_msg_reply).
- **Relay a clear task** to \`gbx-fix\`: the bug (custom format options leak into later calls), that it owns the
  repo at \`$WORKER_REPO\`, and that it must REPRODUCE -> find the ROOT cause (not a band-aid) -> smallest correct
  fix -> ADD a regression test that FAILS on the buggy code and passes after -> keep the suite green -> commit ->
  report root cause + files + commit + verification. Tell it to touch no other repo.
- After gbx-fix reports, **verify read-only**: the fix addresses the ROOT cause (not a symptom band-aid), a
  regression test was added that would've caught the bug, the suite is green, tree clean. If it's a band-aid or
  the test is missing/weak, send it back.
- **Confirm completion back to \`$REQUESTER\`** with the root cause, the commit, and your verification.
- **Autonomy:** run the whole loop with no further human input after the kick. When confirmed, set status and stop.

LANE
else
cat > "$out" <<LANE
# $id — eval WORKER / specialist (Ghost-bug / debug run, full-Codex team)

You are \`$id\` on smalltalk/coord. You own exactly one repo: the \`labelkit\` library at \`$WORKER_REPO\`
(your current directory).

## Hard rules — this is exactly what is being tested
- A supervisor (\`gbx-sup\`) will send you a debugging task by coord message (you'll be woken to it via your ding sidecar).
- Work **in YOUR repo only** (\`$WORKER_REPO\`). **Never touch any other repo or path.**
- Do real debugging: **reproduce** the bug first, find the **ROOT cause** (the actual defect — do NOT paper over
  the symptom), make the **smallest correct fix**, and **add a regression test** that FAILS on the buggy code and
  passes after your fix. Keep the whole suite green (\`npm test\`).
- **Commit** your change in your repo.
- **Report back to \`gbx-sup\`** by coord message: the root cause (what was wrong + why the tests missed it), files
  changed, the commit hash + message, the new regression test, and your verification.
- Coordinate only through coord. Stay in your lane.

LANE
fi

cat >> "$out" <<'BOOT'
---
## Coord boot ritual (do this first, every fresh start)
1. Set your status available: shell out `coord status <your-identity> --set available` (use $COORD_IDENTITY).
2. Drain your inbox: list messages, read each, reply if warranted, archive it. Don't leave inbox items.
3. Then act (supervisor: the seeded bug report; worker: await/handle the delegation).
Your coord correspondent is your interlocutor — questions/blockers/"done" all go through coord messages,
not your own screen (nobody reads your REPL).

BOOT

{ echo '---'; echo '## BASE — development practices (every coding agent inherits this)'; echo; cat "$PZ/dev-practices.md"; echo; } >> "$out"
{ echo '---'; echo '## BASE — known harness bugs'; echo; cat "$PZ/known-harness-bugs.md"; echo; } >> "$out"
{ echo '---'; echo "## ROLE persona ($(basename "$rolefile"))"; echo; cat "$rolefile"; echo; } >> "$out"

echo "composed $out  ($(wc -l < "$out") lines) role=$role id=$id family=codex"
