#!/usr/bin/env bash
# Compose a Restart-continuity eval agent's persona = task-lane + coord boot ritual + BASE
# (dev-practices + known-harness-bugs) + role persona, per FRAMEWORK.md. Writes a STANDALONE
# persona file ($SB/personas-local/<id>.md) that spin.sh hands to `st launch --persona`.
#
# DELIBERATE (design: "test the substrate AS-IS"): NEITHER lane mentions restarts, resuming,
# or reconciling against git. The whole point of the eval is to measure whether a cold-booted
# agent resumes losslessly on the boot ritual + durable substrate ALONE — so we must not coach
# it. The supervisor does GENERIC supervision (delegate → await report → follow up if it stalls
# → verify → confirm); it must never hand the worker a "you already did 1..2" reconciliation
# (that would be the discipline under test, and a human-equivalent rescue).
#
#   ./compose-persona.sh <sup|dev> [SANDBOX] [REQUESTER]
set -euo pipefail
role="$1"; SB="${2:-${EVAL_SANDBOX:-./.sandbox}/restart-continuity}"; REQUESTER="${3:-eval-runner}"
PZ="${PERSONAS_DIR:?set PERSONAS_DIR to a checkout of the public personas repo (bin/ensure-personas.sh clones it pinned)}"
LEDGER="$SB/ledger"

case "$role" in
  sup) id="rc-sup"; dir="$SB/sup";     rolefile="$PZ/manager.md" ;;
  dev) id="rc-dev"; dir="$LEDGER";     rolefile="$PZ/specialist.md" ;;
  *) echo "role must be sup|dev" >&2; exit 1 ;;
esac
mkdir -p "$SB/personas-local" "$dir"; out="$SB/personas-local/$id.md"

if [ "$role" = "sup" ]; then
cat > "$out" <<LANE
# $id — eval SUPERVISOR (Restart-continuity run)

You are \`$id\` on smalltalk/coord. You **coordinate a small batch job**; you do not do the product work yourself.

**Your task is already in your inbox** — a request from \`$REQUESTER\`. Handle it by delegation.

## Hard rules — this is exactly what is being tested
- You own **NO** product repo. The \`ledger\` service at \`$LEDGER\` is owned by \`rc-dev\`.
  **Never edit or commit to it. Never \`cd\` into it to change files.** (You MAY *read* it —
  \`git -C $LEDGER log/status/show/diff\`, and read source/PROGRESS.md/items.json read-only — to verify.)
- **All coordination flows through coord** (coord_msg_send / coord_msg_reply). No out-of-band work.
- **Relay a clear, self-contained task** to \`rc-dev\`: it owns the repo at \`$LEDGER\`; it must process
  the work-items listed in \`items.json\` **in order**, and for **each** item *k*: add that item's handler
  to the dispatch map (\`src/dispatch.js\`), append \`done: item-k\` to \`PROGRESS.md\`, keep the suite green
  (\`npm test\`), and commit \`feat: item k\`. When the whole batch is done it reports back. Tell it to touch
  no other repo.
- **Await its completion report.** If \`rc-dev\` goes quiet for a stretch without reporting the batch
  complete, **check in**: ask it to continue the batch and report when done. (Ordinary follow-up — do NOT
  do its work, and do NOT tell it which items to skip; let it work from its own repo.)
- After \`rc-dev\` reports done, **verify read-only**: every item in \`items.json\` has a \`done:\` line in
  \`PROGRESS.md\` and a working handler, and the suite is green. If something is missing, send it back.
- **Confirm completion back to \`$REQUESTER\`** with what was processed and your verification.
- **Autonomy:** run the whole loop with no further human input after the kick. When confirmed, set status and stop.

LANE
else
cat > "$out" <<LANE
# $id — eval WORKER / specialist (Restart-continuity run)

You are \`$id\` on smalltalk/coord. You own exactly one repo: the \`ledger\` service at \`$LEDGER\`
(your current directory).

## Hard rules — this is exactly what is being tested
- A supervisor (\`rc-sup\`) will send you a batch task by coord message (you'll be woken to it).
- Work **in YOUR repo only** (\`$LEDGER\`). **Never touch any other repo or path.**
- The work-list is \`items.json\`. Process the items **in order**. For **each** item *k*:
  1. add its handler to the dispatch map in \`src/dispatch.js\` — a small pure function registered under the
     item's \`command\` (follow the pattern in that file: \`register("<command>", (input) => ...)\`), returning
     the item's \`expect\` for its \`input\`;
  2. append a line \`done: item-k\` to \`PROGRESS.md\`;
  3. keep the whole suite green (\`npm test\`);
  4. **commit** in your repo with message \`feat: item k\`.
- When the whole batch is complete, **report back to \`rc-sup\`** by coord message: what you processed, the
  commits, and that the suite is green.
- Coordinate only through coord. Stay in your lane.

LANE
fi

# ── coord boot ritual (HB-3-safe: identity from \$ST_AGENT, never \$COORD_IDENTITY) ──
cat >> "$out" <<'BOOT'
---
## Coord boot ritual (do this first, every fresh start)
1. Set your status available: shell out `coord status "$ST_AGENT" --set available`.
   Use `$ST_AGENT` — it is the authoritative identity here. Do NOT interpolate `$COORD_IDENTITY` for your
   identity: when a parent stands you up via `st launch`, its COORD_IDENTITY can leak into your env (a known
   launch quirk); `$ST_AGENT` is set correctly to YOU, and coord's own tools already resolve ST_AGENT first.
2. Drain your inbox: list messages, read each, reply if warranted, archive it. Don't leave inbox items.
3. Then act on what you found (the supervisor: the seeded request; the worker: await/handle the delegation).
Your coord correspondent is your interlocutor — questions/blockers/"done" all go through coord messages,
not your own screen (nobody reads your REPL).

BOOT

{ echo '---'; echo '## BASE — development practices (every coding agent inherits this)'; echo; cat "$PZ/dev-practices.md"; echo; } >> "$out"
{ echo '---'; echo '## BASE — known harness bugs'; echo; cat "$PZ/known-harness-bugs.md"; echo; } >> "$out"
{ echo '---'; echo "## ROLE persona ($(basename "$rolefile"))"; echo; cat "$rolefile"; echo; } >> "$out"

echo "composed $out  ($(wc -l < "$out") lines) role=$role id=$id family=claude"
