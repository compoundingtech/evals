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
