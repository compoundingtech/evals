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
