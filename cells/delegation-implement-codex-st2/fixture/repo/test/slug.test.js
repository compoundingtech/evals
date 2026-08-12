import test from "node:test";
import assert from "node:assert/strict";
import { slugify, slugsFor } from "../src/slug.js";

test("slugify normalizes text", () => {
  assert.equal(slugify("Hello World"), "hello-world");
  assert.equal(slugify("  --Trim!!  "), "trim");
  assert.equal(slugify(""), "note");
});

test("slugsFor maps every note", () => {
  const slugs = slugsFor([{ heading: "Alpha" }, { heading: "Beta" }]);
  assert.deepEqual(slugs, ["alpha", "beta"]);
});
