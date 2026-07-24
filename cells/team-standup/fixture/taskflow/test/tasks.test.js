import test from "node:test";
import assert from "node:assert/strict";
import { addTask, listTasks } from "../src/tasks.js";

test("addTask returns an open task with an id", () => {
  const t = addTask("write the changelog");
  assert.equal(t.title, "write the changelog");
  assert.equal(t.done, false);
  assert.ok(t.id > 0);
});

test("addTask rejects an empty title", () => {
  assert.throws(() => addTask("  "), TypeError);
});

test("listTasks returns a copy", () => {
  addTask("ship the beta");
  const a = listTasks();
  a[0].title = "mutated";
  assert.notEqual(listTasks()[0].title, "mutated");
});
