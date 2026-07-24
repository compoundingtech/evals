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
