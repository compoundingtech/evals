#!/usr/bin/env bash
# Materialize the Feature-fit ("Fit in") eval sandbox. A small, non-trivial `tasklit` task-command
# library with STRONG, DISTINCTIVE, CONSISTENT conventions across 4 existing commands — the feature
# must FIT IN idiomatically, not just work. The conventions (unmistakable from reading add/done/remove):
#   K1 Result pattern: code NEVER throws; every run() returns ok(value) / fail(code, message) from result.js.
#   K2 Shared validators: input checks reuse positiveInt / nonEmptyString from validate.js (never inlined).
#   K3 Command-module shape: src/commands/<name>.js exports `{ name, describe, run(args, store) }`,
#      and is REGISTERED in src/commands/index.js (the dispatch registry).
#   K4 Tests: one per command at test/commands/<name>.test.js, node:test, asserting the {ok,...} shape.
# The suite is GREEN. The feature request: add a `rename` command. A careful dev reads done.js/remove.js
# and slots in idiomatically; a careless one throws, inlines validation, forgets to register, or returns
# a raw value — each mechanically detectable. See tasks/feature-fit.toml.
#
#   ./setup-sandbox.sh            # builds ${EVAL_SANDBOX:-./.sandbox}/feature-fit
set -euo pipefail
SB="${1:-${EVAL_SANDBOX:-./.sandbox}/feature-fit}"

echo "== clean =="; rm -rf "$SB"; mkdir -p "$SB/sup"        # sup/ = coordinate-only, owns NO repo
W="$SB/worker"; mkdir -p "$W/src/commands" "$W/test/commands"

echo "== worker repo: tasklit (established conventions across 4 commands) =="
cat > "$W/src/result.js" <<'JS'
// The Result type used everywhere in tasklit. Code never throws for expected outcomes;
// it returns one of these. Success carries a value; failure carries a stable `code` + message.
export function ok(value) {
  return { ok: true, value };
}
export function fail(code, message) {
  return { ok: false, code, message };
}
JS

cat > "$W/src/validate.js" <<'JS'
// Shared input validators. Commands reuse these rather than inlining checks.
export function nonEmptyString(x) {
  return typeof x === "string" && x.trim().length > 0;
}
export function positiveInt(x) {
  return Number.isInteger(x) && x > 0;
}
JS

cat > "$W/src/store.js" <<'JS'
// A tiny in-memory task store. Tasks are { id, title, done }. Ids are assigned sequentially.
export function createStore(seed = []) {
  const tasks = seed.map((t) => ({ ...t }));
  let seq = tasks.reduce((m, t) => Math.max(m, t.id), 0);
  return {
    all: () => tasks,
    find: (id) => tasks.find((t) => t.id === id),
    insert: ({ title }) => {
      const task = { id: ++seq, title, done: false };
      tasks.push(task);
      return task;
    },
  };
}
JS

cat > "$W/src/commands/add.js" <<'JS'
import { ok, fail } from "../result.js";
import { nonEmptyString } from "../validate.js";

export const add = {
  name: "add",
  describe: "Add a task",
  run(args, store) {
    if (!nonEmptyString(args.title)) return fail("invalid", "title must be a non-empty string");
    return ok(store.insert({ title: args.title }));
  },
};
JS

cat > "$W/src/commands/list.js" <<'JS'
import { ok } from "../result.js";

export const list = {
  name: "list",
  describe: "List all tasks",
  run(args, store) {
    return ok(store.all());
  },
};
JS

cat > "$W/src/commands/done.js" <<'JS'
import { ok, fail } from "../result.js";
import { positiveInt } from "../validate.js";

export const done = {
  name: "done",
  describe: "Mark a task done by id",
  run(args, store) {
    if (!positiveInt(args.id)) return fail("invalid", "id must be a positive integer");
    const task = store.find(args.id);
    if (!task) return fail("not_found", `no task with id ${args.id}`);
    task.done = true;
    return ok(task);
  },
};
JS

cat > "$W/src/commands/remove.js" <<'JS'
import { ok, fail } from "../result.js";
import { positiveInt } from "../validate.js";

export const remove = {
  name: "remove",
  describe: "Remove a task by id",
  run(args, store) {
    if (!positiveInt(args.id)) return fail("invalid", "id must be a positive integer");
    const task = store.find(args.id);
    if (!task) return fail("not_found", `no task with id ${args.id}`);
    const tasks = store.all();
    tasks.splice(tasks.indexOf(task), 1);
    return ok(task);
  },
};
JS

cat > "$W/src/commands/index.js" <<'JS'
import { add } from "./add.js";
import { list } from "./list.js";
import { done } from "./done.js";
import { remove } from "./remove.js";
import { fail } from "../result.js";

// The command registry. Every command is listed here so `dispatch` can find it by name.
export const commands = [add, list, done, remove];

export function dispatch(name, args, store) {
  const cmd = commands.find((c) => c.name === name);
  if (!cmd) return fail("unknown_command", `no such command: ${name}`);
  return cmd.run(args, store);
}
JS

# Tests — one per command, establishing the style (node:test, assert on the {ok,...} shape).
cat > "$W/test/commands/add.test.js" <<'JS'
import test from "node:test";
import assert from "node:assert/strict";
import { createStore } from "../../src/store.js";
import { add } from "../../src/commands/add.js";

test("add: inserts a task and returns ok(task)", () => {
  const store = createStore();
  const r = add.run({ title: "write docs" }, store);
  assert.equal(r.ok, true);
  assert.equal(r.value.title, "write docs");
  assert.equal(r.value.done, false);
});

test("add: invalid for an empty title", () => {
  const r = add.run({ title: "  " }, createStore());
  assert.equal(r.ok, false);
  assert.equal(r.code, "invalid");
});
JS

cat > "$W/test/commands/done.test.js" <<'JS'
import test from "node:test";
import assert from "node:assert/strict";
import { createStore } from "../../src/store.js";
import { done } from "../../src/commands/done.js";

test("done: marks an existing task done", () => {
  const store = createStore([{ id: 1, title: "a", done: false }]);
  const r = done.run({ id: 1 }, store);
  assert.equal(r.ok, true);
  assert.equal(r.value.done, true);
});

test("done: not_found for a missing id", () => {
  const r = done.run({ id: 9 }, createStore());
  assert.deepEqual(r, { ok: false, code: "not_found", message: "no task with id 9" });
});

test("done: invalid for a non-positive id", () => {
  const r = done.run({ id: 0 }, createStore());
  assert.equal(r.ok, false);
  assert.equal(r.code, "invalid");
});
JS

cat > "$W/test/commands/remove.test.js" <<'JS'
import test from "node:test";
import assert from "node:assert/strict";
import { createStore } from "../../src/store.js";
import { remove } from "../../src/commands/remove.js";

test("remove: deletes an existing task", () => {
  const store = createStore([{ id: 1, title: "a", done: false }]);
  const r = remove.run({ id: 1 }, store);
  assert.equal(r.ok, true);
  assert.equal(store.all().length, 0);
});

test("remove: not_found for a missing id", () => {
  const r = remove.run({ id: 9 }, createStore());
  assert.equal(r.ok, false);
  assert.equal(r.code, "not_found");
});
JS

cat > "$W/test/commands/dispatch.test.js" <<'JS'
import test from "node:test";
import assert from "node:assert/strict";
import { createStore } from "../../src/store.js";
import { dispatch } from "../../src/commands/index.js";

test("dispatch: routes to a registered command", () => {
  const r = dispatch("add", { title: "x" }, createStore());
  assert.equal(r.ok, true);
});

test("dispatch: unknown_command for an unregistered name", () => {
  const r = dispatch("nope", {}, createStore());
  assert.deepEqual(r, { ok: false, code: "unknown_command", message: "no such command: nope" });
});
JS

cat > "$W/package.json" <<'JSON'
{
  "name": "tasklit",
  "version": "1.2.0",
  "private": true,
  "type": "module",
  "description": "A tiny task-command library.",
  "main": "src/commands/index.js",
  "scripts": { "test": "node --test" }
}
JSON

cat > "$W/README.md" <<'MD'
# tasklit

A tiny task-command library. Commands live in `src/commands/` and are dispatched by name.

```js
import { createStore } from "./src/store.js";
import { dispatch } from "./src/commands/index.js";

const store = createStore();
dispatch("add", { title: "buy milk" }, store); // { ok: true, value: { id: 1, title: "buy milk", done: false } }
dispatch("done", { id: 1 }, store);            // { ok: true, value: { id: 1, title: "buy milk", done: true } }
dispatch("list", {}, store);                   // { ok: true, value: [ ... ] }
```

Available commands: `add`, `list`, `done`, `remove`. Run the tests with `npm test`.
MD

cat > "$W/.gitignore" <<'GI'
node_modules/
.DS_Store
CLAUDE.md
AGENTS.md
.mcp.json
.claude-session-id
.claude/
pty.toml
pty.toml.done
GI

echo "== git init worker repo (frozen base) + distinct author =="
git -C "$W" init -q -b main
git -C "$W" add -A
git -C "$W" -c user.name="evals-seed" -c user.email="seed@local" commit -q -m "tasklit: task-command library v1.2.0"
git -C "$W" config user.name  "feat-dev"
git -C "$W" config user.email "feat-dev@eval.local"
BASE="$(git -C "$W" rev-parse --short HEAD)"

echo
echo "== VALIDATE invariants =="
# 1) existing suite GREEN
( cd "$W" && node --test >/dev/null 2>&1 && echo "  [ok] suite GREEN (4 command modules + dispatch)" || { echo "  [!!] suite RED"; exit 1; } )

# 2) the feature is NOT already present
[ -f "$W/src/commands/rename.js" ] && { echo "  [!!] rename already present"; exit 1; } || echo "  [ok] rename not yet present (the feature to add)"

# 3) SOLVABLE: apply a REFERENCE idiomatic rename on a scratch copy -> suite green + functional cases pass
SC=$(mktemp -d); cp -r "$W" "$SC/w"; rm -rf "$SC/w/.git"
cat > "$SC/w/src/commands/rename.js" <<'JS'
import { ok, fail } from "../result.js";
import { positiveInt, nonEmptyString } from "../validate.js";
export const rename = {
  name: "rename",
  describe: "Rename a task by id",
  run(args, store) {
    if (!positiveInt(args.id)) return fail("invalid", "id must be a positive integer");
    if (!nonEmptyString(args.title)) return fail("invalid", "title must be a non-empty string");
    const task = store.find(args.id);
    if (!task) return fail("not_found", `no task with id ${args.id}`);
    task.title = args.title;
    return ok(task);
  },
};
JS
# register it (idiomatic): add import + into the commands array
perl -0pi -e 's/import \{ remove \} from ".\/remove.js";/import { remove } from ".\/remove.js";\nimport { rename } from ".\/rename.js";/' "$SC/w/src/commands/index.js"
perl -0pi -e 's/export const commands = \[add, list, done, remove\];/export const commands = [add, list, done, remove, rename];/' "$SC/w/src/commands/index.js"
REF=$(cd "$SC/w" && node --input-type=module -e '
import { createStore } from "./src/store.js";
import { dispatch } from "./src/commands/index.js";
const s = createStore([{id:1,title:"old",done:false},{id:2,title:"two",done:false}]);
const a = dispatch("rename",{id:1,title:"New"},s);
const b = dispatch("rename",{id:99,title:"X"},s);
const c = dispatch("rename",{id:1,title:""},s);
const d = dispatch("rename",{id:0,title:"X"},s);
const okc = a.ok && a.value.title==="New" && !b.ok && b.code==="not_found" && !c.ok && c.code==="invalid" && !d.ok && d.code==="invalid";
console.log(okc ? "REF-OK" : "REF-BAD "+JSON.stringify({a,b,c,d}));
' 2>&1)
( cd "$SC/w" && node --test >/dev/null 2>&1 ) && SUITE=green || SUITE=RED
echo "  reference rename: $REF ; scratch suite: $SUITE"
{ [ "$REF" = "REF-OK" ] && [ "$SUITE" = green ]; } && echo "  [ok] SOLVABLE: an idiomatic rename passes the functional grade + keeps the suite green" || { echo "  [!!] reference solution failed"; rm -rf "$SC"; exit 1; }
rm -rf "$SC"

echo
echo "SANDBOX READY: $SB   (worker base $BASE; author feat-dev)"
echo "  worker/  tasklit (owned by feat-dev; GREEN suite; 4 commands establishing the conventions; NO rename yet)"
echo "  sup/     coordinate-only (feat-sup cwd; owns no repo)"
echo "next: compose personas + wire agents (sup=bypass, dev=auto), seed the feature request, spin; grade.sh checks fit + function."
