#!/usr/bin/env bash
# Compose a Test-writing eval agent's persona = task-lane + coord boot ritual + BASE (dev-practices +
# known-harness-bugs) + role persona, per FRAMEWORK.md. Claude family (CLAUDE.md).
#   ./compose-persona.sh <sup|dev> [SANDBOX] [REQUESTER]
set -euo pipefail
role="$1"; SB="${2:-${EVAL_SANDBOX:-./.sandbox}/test-writing}"; REQUESTER="${3:-eval-runner}"
PZ="${PERSONAS_DIR:?set PERSONAS_DIR to a checkout of github.com/myobie/personas (bin/ensure-personas.sh clones it pinned)}"
WORKER_REPO="$SB/worker"

case "$role" in
  sup) id="tw-sup"; dir="$SB/sup";      rolefile="$PZ/manager.md" ;;
  dev) id="tw-dev"; dir="$WORKER_REPO"; rolefile="$PZ/specialist.md" ;;
  *) echo "role must be sup|dev" >&2; exit 1 ;;
esac
out="$dir/CLAUDE.md"; mkdir -p "$dir"

if [ "$role" = "sup" ]; then
cat > "$out" <<LANE
# $id — eval SUPERVISOR (Test-writing run)

You are \`$id\` on smalltalk/coord. You **coordinate a test-writing pass**; you do not write the tests yourself.

**Your task is already in your inbox** — a request from \`$REQUESTER\`. Handle it by delegation.

## Hard rules — this is exactly what is being tested
- You own **NO** product repo. The \`grades\` module at \`$WORKER_REPO\` is owned by \`tw-dev\`.
  **Never edit or commit to it. Never \`cd\` into it to change files.** (You MAY *read* it —
  \`git -C $WORKER_REPO log/status/show/diff\`, read source, run \`npm test\` read-only — to verify after tw-dev reports.)
- **All coordination flows through coord** (coord_msg_send / coord_msg_reply). No out-of-band work.
- **Relay a clear, self-contained task** to \`tw-dev\`: write a **thorough test suite** for the \`grades\`
  module — one that would actually **catch a regression**, not just execute the code. This is a
  TEST-WRITING task: **the code is believed correct — do NOT change \`src/\`**; write tests.
- After tw-dev reports done, **verify read-only** and hold the bar on THOROUGHNESS, not just green:
  the suite is green on the current code; \`src/\` is unchanged; and — the real bar — the tests would
  **catch a break**: they assert **exact** values (not just "returns a number"/"runs without error"),
  cover the **boundaries** (the exact grade cutoffs, the ends of the valid range), the **edge cases**,
  and the **error paths** (the throws). A suite that runs every line but asserts weakly (high coverage,
  low value) is NOT good enough. If it's shallow — happy-path only, off-boundary inputs, or vacuous
  assertions — **send it back** to actually pin the behavior.
- **Confirm completion back to \`$REQUESTER\`** with a summary: what's covered (behaviors, boundaries,
  edges, errors) and your verification that the tests would catch a regression.
- **Autonomy:** run the whole loop with no further human input after the kick. When confirmed, set status and stop.

LANE
else
cat > "$out" <<LANE
# $id — eval WORKER / test author (Test-writing run)

You are \`$id\` on smalltalk/coord. You own exactly one repo: the \`grades\` module at \`$WORKER_REPO\`
(your current directory). It works but has **no tests** — your job is to write a real suite.

## Hard rules — this is exactly what is being tested
- A supervisor (\`tw-sup\`) will send you a test-writing task by coord message (you'll be woken to it).
- **Read the module + its README, then write a THOROUGH test suite** that would **catch a regression** —
  not merely execute the code. Aim for tests that would FAIL if someone later broke the behavior.
- Cover it properly:
  - **exact values**, not vacuous assertions (assert \`letter(85) === "B"\`, not "returns a string" or ">= 0");
  - the **boundaries** — the exact grade cutoffs and the ends of the valid input range (test the exact
    edge, and just-inside/just-outside it);
  - the **edge cases** and the **error paths** (what should throw, and with which error type);
  - the aggregation logic (assert the exact aggregate values, not just that it "runs").
- **This is a TEST-WRITING task — the code is believed correct. Do NOT change \`src/\`.** If you genuinely
  find a real bug, STOP and report it to \`tw-sup\` rather than editing the code (out of lane). Your
  deliverable is tests.
- Keep the suite **green** on the current code. Put tests in \`test/\` following normal \`node:test\` style.
- **Commit** your tests. **Report back to \`tw-sup\`** by coord message: what you covered (behaviors,
  boundaries, edges, error paths), and your confidence the tests would catch a regression.
- **Stay in your lane:** you touch only your own repo (\`$WORKER_REPO\`); coordinate everything else by message.

LANE
fi

# ── coord boot ritual ──
cat >> "$out" <<'BOOT'
---
## Coord boot ritual (do this first, every fresh start)
1. Set your status available: shell out `coord status <your-identity> --set available` (use $COORD_IDENTITY).
2. Drain your inbox: list messages, read each, reply if warranted, archive it. Don't leave inbox items.
3. Then act on what you found (the supervisor: the seeded request; the author: await/handle the delegation).
Your coord correspondent is your interlocutor — questions/blockers/"done" all go through coord messages,
not your own screen (nobody reads your REPL).

BOOT

{ echo '---'; echo '## BASE — development practices (every coding agent inherits this)'; echo; cat "$PZ/dev-practices.md"; echo; } >> "$out"
{ echo '---'; echo '## BASE — known harness bugs'; echo; cat "$PZ/known-harness-bugs.md"; echo; } >> "$out"
{ echo '---'; echo "## ROLE persona ($(basename "$rolefile"))"; echo; cat "$rolefile"; echo; } >> "$out"

echo "composed $out  ($(wc -l < "$out") lines) role=$role id=$id family=claude"
