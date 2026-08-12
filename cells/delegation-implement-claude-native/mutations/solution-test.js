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

test("slugsFor suffixes colliding headings in input order", () => {
  assert.deepEqual(
    slugsFor([{ heading: "Alpha" }, { heading: "Alpha" }, { heading: "Beta" }, { heading: "Alpha" }]),
    ["alpha", "alpha-2", "beta", "alpha-3"],
  );
});

test("slugsFor suffixes colliding empty headings", () => {
  assert.deepEqual(slugsFor([{ heading: "" }, { heading: "  " }]), ["note", "note-2"]);
});
