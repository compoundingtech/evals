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
