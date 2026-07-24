import test from "node:test";
import assert from "node:assert/strict";
import { slugify } from "../src/slug.js";

test("slugify is exported as a function", () => {
  assert.equal(typeof slugify, "function");
});
