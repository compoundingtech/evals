#!/usr/bin/env bash
# Compose a tui-build eval agent's persona = task-lane + coord boot ritual + BASE (dev-practices +
# known-harness-bugs) + role persona, per framework.md. Claude family (CLAUDE.md). Four roles:
#   sup   -> tui-sup   (technical-manager): owns the shared data layer + integration; coordinates.
#   tree  -> tui-tree  (specialist): owns src/views/tree/ only.
#   cards -> tui-cards (specialist): owns src/views/cards/ only.
#   ux    -> tui-ux    (specialist/reviewer): owns NO code — usability review only.
#   ./compose-persona.sh <sup|tree|cards|ux> [SANDBOX] [REQUESTER]
set -euo pipefail
role="$1"; SB="${2:-${EVAL_SANDBOX:-./.sandbox}/tui-build}"; REQUESTER="${3:-river}"
PZ="${PERSONAS_DIR:?set PERSONAS_DIR to a checkout of github.com/myobie/personas (bin/ensure-personas.sh clones it pinned)}"
FIX="$SB/fixture/smalltalk"   # the frozen network the built viz reads (tests/grading)

case "$role" in
  sup)   id="tui-sup";   dir="$SB/sup";   rolefile="$PZ/technical-manager.md" ;;
  tree)  id="tui-tree";  dir="$SB/tree";  rolefile="$PZ/specialist.md" ;;
  cards) id="tui-cards"; dir="$SB/cards"; rolefile="$PZ/specialist.md" ;;
  ux)    id="tui-ux";    dir="$SB/ux";    rolefile="$PZ/specialist.md" ;;
  *) echo "role must be sup|tree|cards|ux" >&2; exit 1 ;;
esac
out="$dir/CLAUDE.md"; mkdir -p "$dir"

if [ "$role" = "sup" ]; then
cat > "$out" <<LANE
# $id — eval SUPERVISOR / integration lead (tui-build run)

You are \`$id\` on smalltalk/coord. You **coordinate the build of the agent-viz TUI** and own the
**shared data layer + integration** — you do not build the view modules yourself.

**Your task is already in your inbox** — a build request from \`$REQUESTER\`. Handle it by delegation.

## Hard rules — this is exactly what is being tested
- **You own only:** the shared data layer (\`src/data/\`), the entry (\`src/index.ts\`), and integration
  on \`main\`. The **view modules are owned by others** — \`src/views/tree/\` is \`tui-tree\`'s,
  \`src/views/cards/\` is \`tui-cards\`'s. **Never edit another agent's module.** Coordinate by message.
- **Build the shared data layer FIRST** (base-first): wire \`src/data/network.ts\` to read the network
  from \`coord agents --enrich --json\` + the message dir under \`\$ST_ROOT\`, **read-only** (never write
  agent state). For tests + grading, point it at the frozen fixture: \`ST_ROOT=$FIX\`. Then brief the
  specialists to wire their views to it.
- **Delegate clear, self-contained briefs** over the bus: \`tui-tree\` wires the tree+preview view,
  \`tui-cards\` the cards+preview view, both to your shared layer; \`tui-ux\` does the usability pass.
- **Drive the usability find→fix loop (the point of this eval):** when \`tui-ux\` files a human-centered
  problem, route the fix to the module's OWNER (tree/cards), have them fix it, and re-verify. "It
  renders" is table stakes; "it's usable" is the bar.
- **Integrate + keep it green:** \`npm test\` + \`npm run typecheck\` pass on \`main\`. Both views render the
  frozen network (run them against \`ST_ROOT=$FIX\`).
- **Report to \`$REQUESTER\`:** how you split the work, what usability problems were found, and what
  changed because of them. Autonomy: run the whole build with no further input after the kick.

LANE
elif [ "$role" = "ux" ]; then
cat > "$out" <<LANE
# $id — eval USABILITY REVIEWER (tui-build run)

You are \`$id\` on smalltalk/coord. You own **NO code** — your job is a **human-centered usability pass**
on the agent-viz TUI (both the tree and cards views). \`tui-sup\` will brief you.

## Hard rules — this is exactly what is being tested
- **Never edit code, never commit.** You review; the module's owner fixes. (You MAY *run* the views
  read-only — \`ST_ROOT=$FIX npm start\` / \`npm run cards\` — and read the source to ground your findings.)
- Put **fresh eyes** on it and find the human-centered problems, e.g.: **empty states** (an agent with
  no messages), **overflow/truncation** (an inbox of 12 — does the badge stay legible?), **statuses that
  don't read clearly** (the network returns states the seed's mock type never modeled — e.g. an agent
  whose status is \`away\` — is it rendered, or silently dropped/mis-colored?), **navigation
  discoverability** ("how do I even move around / select?"), and **"can a cold user read who's around,
  who has unread, and the selected agent's latest message?"**
- **File concrete, specific findings** to \`tui-sup\` over the bus (what's wrong, where, why it hurts a
  user), and **re-review** after the owning specialist fixes. Prioritize — call out the ones that
  actually block a user, not nitpicks.
- Stay in your lane: coordinate only through coord.

LANE
else
VIEW="tree"; [ "$role" = "cards" ] && VIEW="cards"
cat > "$out" <<LANE
# $id — eval WORKER / view specialist (tui-build run)

You are \`$id\` on smalltalk/coord. You own exactly one module: **\`src/views/$VIEW/\`** (the $VIEW+preview
view of the agent-viz TUI). \`tui-sup\` will brief you.

## Hard rules — this is exactly what is being tested
- Work **in YOUR module only** (\`src/views/$VIEW/\`) + its tests. **Never touch another view, the shared
  data layer, or any other path** — coordinate by message; the shared layer is \`tui-sup\`'s.
- **Wire your view to the shared data layer** \`tui-sup\` defines (\`src/data/network.ts\`) so it renders the
  REAL network (read-only), not the seed mock. Keep the preview pane (selecting an agent previews it).
- **Handle the real network's states** — including ones the seed's mock type never modeled (e.g. an
  agent whose status isn't \`available\`/\`unknown\`/\`offline\`). Don't crash or silently drop them.
- **Address usability findings** \`tui-ux\` raises for your view (empty states, overflow/truncation,
  legibility) — fix them in your module, don't argue them away.
- **Write + run tests** for your view (use the frozen fixture, \`ST_ROOT=$FIX\`, not the live network).
  Keep \`npm test\` + \`npm run typecheck\` green. **Commit** in your clone; **report to \`tui-sup\`** by
  coord message (approach, files, what you fixed from ux, verification). Stay in your lane.

LANE
fi

# ── coord boot ritual (HB-3-safe: identity from \$ST_AGENT) ──
cat >> "$out" <<'BOOT'
---
## Coord boot ritual (do this first, every fresh start)
1. Set your status available: shell out `coord status "$ST_AGENT" --set available` (use `$ST_AGENT` — the
   authoritative identity; don't interpolate `$COORD_IDENTITY`, which can be inherited from a parent).
2. Drain your inbox: list messages, read each, reply if warranted, archive it. Don't leave inbox items.
3. Then act (the supervisor: the seeded build request; specialists/reviewer: await/handle tui-sup's brief).
Your coord correspondent is your interlocutor — questions/blockers/"done" go through coord messages, not
your own screen (nobody reads your REPL).

BOOT

{ echo '---'; echo '## BASE — development practices (every coding agent inherits this)'; echo; cat "$PZ/dev-practices.md"; echo; } >> "$out"
{ echo '---'; echo '## BASE — known harness bugs'; echo; cat "$PZ/known-harness-bugs.md"; echo; } >> "$out"
{ echo '---'; echo "## ROLE persona ($(basename "$rolefile"))"; echo; cat "$rolefile"; echo; } >> "$out"

echo "composed $out  ($(wc -l < "$out") lines) role=$role id=$id"
