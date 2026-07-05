#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# Materialize the RESTART-CONTINUITY (durability) eval sandbox. A small `ledger`
# service with a tiny command-dispatch core and a 4-item work-list. The worker's
# job (seeded via the hermetic kick — nothing about restarts in it): process
# work-items 1..4 IN ORDER; for each item k, add its handler to the dispatch map
# (`src/dispatch.js`), append `done: item-k` to PROGRESS.md, and commit `feat: item k`.
#
# The runner cold-restarts the worker mid-batch (see restart-injector.sh). This
# cell measures whether a cold-booted agent — no prior transcript, only the
# durable substrate (git log + PROGRESS.md + items.json + the bus) — resumes
# LOSSLESSLY: every item ends up done at least once (the hard gate), no item is
# skipped, and a redo does not corrupt.
#
# WHY THE OPS ARE IDEMPOTENT (the durability lesson):
#   - items.json is the durable ground truth of WHAT work exists (never mutated).
#   - register(command, handler) in src/dispatch.js is LAST-WINS: re-registering
#     the same command overwrites with an identical handler — a redo is harmless.
#   - The ground truth of WHAT'S DONE is unambiguous: git log + PROGRESS.md.
#   So a redo (item processed twice) is a tolerated DUPLICATE, not corruption —
#   which is exactly how an at-least-once system is supposed to behave.
#
#   ./setup-sandbox.sh [SANDBOX]      # builds ${EVAL_SANDBOX:-./.sandbox}/restart-continuity
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail
SB="${1:-${EVAL_SANDBOX:-./.sandbox}/restart-continuity}"

echo "== clean =="; rm -rf "$SB"; mkdir -p "$SB/sup"       # sup/ = coordinate-only, owns NO repo
L="$SB/ledger"; mkdir -p "$L/src" "$L/test"

echo "== work-list: the durable ground truth of WHAT to do (items.json) =="
cat > "$L/items.json" <<'JSON'
{
  "items": [
    { "id": "item-1", "command": "upper",   "input": "hello",   "expect": "HELLO",   "desc": "uppercase the input string" },
    { "id": "item-2", "command": "reverse", "input": "abc",     "expect": "cba",     "desc": "reverse the input string" },
    { "id": "item-3", "command": "exclaim", "input": "hi",      "expect": "hi!",     "desc": "append an exclamation mark" },
    { "id": "item-4", "command": "dashify", "input": "a b c",   "expect": "a-b-c",   "desc": "replace spaces with dashes" }
  ]
}
JSON

echo "== dispatch core: register() is LAST-WINS (idempotent redo) =="
cat > "$L/src/dispatch.js" <<'JS'
// A tiny command-dispatch core for the `ledger` service.
//
// register() is LAST-WINS BY DESIGN: registering the same command twice just
// overwrites the handler with an identical one — so re-processing a work-item is
// harmless (no duplicate-registration corruption). That is the durability
// property this service leans on: an at-least-once pipeline makes each step
// idempotent, so a retried/redone step never breaks the artifact.
const handlers = new Map();

export function register(command, handler) {
  handlers.set(command, handler); // last-wins: a redo re-registers the same handler harmlessly
}

export function dispatch(command, input) {
  const handler = handlers.get(command);
  if (!handler) throw new Error(`no handler registered for command: ${command}`);
  return handler(input);
}

// The sorted list of registered command names (no duplicates — a Map has unique keys).
export function registered() {
  return [...handlers.keys()].sort();
}

// ── work-item handlers ───────────────────────────────────────────────────────
// One handler is added here per work-item (see items.json), in order. Each is a
// small pure function registered under its command name, e.g.
//
//     register("upper", (input) => String(input).toUpperCase());
//
// (none yet — the batch adds item-1..item-4)
JS

echo "== visible suite: GREEN at seed, stays GREEN as handlers are added =="
cat > "$L/test/dispatch.test.js" <<'JS'
import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";
import { register, dispatch, registered } from "../src/dispatch.js";

const here = dirname(fileURLToPath(import.meta.url));
const items = JSON.parse(readFileSync(join(here, "../items.json"), "utf8")).items;

// ── machinery (green from seed, before any item is processed) ──
test("dispatch throws for an unregistered command", () => {
  assert.throws(() => dispatch("does-not-exist", "x"));
});

test("register is last-wins, and registered() reports each command once", () => {
  register("__probe", () => "a");
  register("__probe", () => "b");
  assert.equal(dispatch("__probe", null), "b");            // last-wins
  assert.equal(registered().filter((k) => k === "__probe").length, 1); // no duplicate keys
});

// ── internal consistency: every command that IS registered dispatches to its
// spec. Vacuously green at seed (nothing registered); stays green after each
// correctly-processed item. This is the "keep the suite green" target — it does
// NOT assert completeness (that every item is done); completeness is the
// held-out grade, so a partially-done batch is still green.
for (const it of items) {
  test(`if '${it.command}' is registered it dispatches correctly (${it.id})`, () => {
    if (registered().includes(it.command)) {
      assert.equal(dispatch(it.command, it.input), it.expect);
    }
  });
}
JS

echo "== progress ledger: the durable record of WHAT'S DONE (append-only) =="
cat > "$L/PROGRESS.md" <<'MD'
# PROGRESS

Batch: process the work-items in `items.json` in order. As each item *k* is
completed, append a line `done: item-k` below and commit `feat: item k`.

MD

cat > "$L/package.json" <<'JSON'
{
  "name": "ledger",
  "version": "0.1.0",
  "private": true,
  "type": "module",
  "description": "A tiny command-dispatch service processed in an ordered, idempotent batch.",
  "main": "src/dispatch.js",
  "scripts": { "test": "node --test" }
}
JSON

cat > "$L/README.md" <<'MD'
# ledger

A tiny command-dispatch service. Handlers are registered into a dispatch map and
looked up by command name:

```js
import { register, dispatch } from "./src/dispatch.js";
register("upper", (s) => String(s).toUpperCase());
dispatch("upper", "hi");   // "HI"
```

`register()` is **last-wins** — registering the same command twice is harmless.
The work-list lives in `items.json`; `PROGRESS.md` records what's done. Run the
tests with `npm test`.
MD

cat > "$L/.gitignore" <<'GI'
node_modules/
.DS_Store
CLAUDE.md
AGENTS.md
PERSONA.md
.mcp.json
.claude-session-id
.claude/
pty.toml
pty.toml.done
GI

echo "== git init ledger repo (frozen base) + distinct author (rc-dev) =="
git -C "$L" init -q -b main
git -C "$L" add -A
git -C "$L" -c user.name="evals-seed" -c user.email="seed@local" commit -q -m "ledger: dispatch core + work-list (green suite, no items processed yet)"
git -C "$L" config user.name  "rc-dev"
git -C "$L" config user.email "rc-dev@eval.local"
BASE="$(git -C "$L" rev-parse --short HEAD)"

echo "== sanity: suite is GREEN at seed (no items processed) =="
( cd "$L" && node --test >/dev/null 2>&1 && echo "  suite: GREEN (as designed — vacuous item checks pass)" || echo "  !! suite unexpectedly RED at seed" )
echo "== sanity: dispatch is empty at seed (registered() == []) =="
REG=$(cd "$L" && node --input-type=module -e '
import { registered } from "./src/dispatch.js";
console.log(JSON.stringify(registered()));
' 2>&1)
echo "  registered() => $REG   (must be [] — the batch fills it)"

echo
echo "SANDBOX READY: $SB   (ledger base $BASE; author rc-dev)"
echo "  ledger/  the command-dispatch service (owned by rc-dev; GREEN suite; 4 items pending in items.json)"
echo "  sup/     coordinate-only (rc-sup cwd; owns no repo)"
echo "next: compose personas + launch (sup=bypass, dev=auto), seed the kick into rc-sup inbox, spin, then the"
echo "      restart-injector cold-restarts rc-dev after item 2 lands. Grade with grade.sh."
