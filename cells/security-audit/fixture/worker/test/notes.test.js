import test from "node:test";
import assert from "node:assert/strict";
import { greet } from "../src/util.js";
import { isAuthorized } from "../src/auth.js";

test("greet falls back to English", () => {
  assert.equal(greet("xx"), "Hello");
  assert.equal(greet("fr"), "Bonjour");
});

test("a correct token authorizes", () => {
  assert.equal(isAuthorized("apptoken_a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6"), true);
});
