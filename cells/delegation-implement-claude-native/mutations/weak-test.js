import test from "node:test";
import assert from "node:assert/strict";
import { slugify, slugsFor } from "../src/slug.js";

test("slugify normalizes text", () => {
  assert.equal(slugify("Hello World"), "hello-world");
  assert.equal(slugify("  --Trim!!  "), "trim");
  assert.equal(slugify(""), "note");
});

// Planted negative: a "regression test" that never puts two colliding headings in one call, so it is green
// against the pre-change implementation too.
test("slugsFor maps every note", () => {
  assert.deepEqual(slugsFor([{ heading: "Alpha" }, { heading: "Beta" }]), ["alpha", "beta"]);
  assert.equal(slugsFor([{ heading: "Alpha" }]).length, 1);
});
