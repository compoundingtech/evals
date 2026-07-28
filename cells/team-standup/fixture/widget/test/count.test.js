import test from "node:test";
import assert from "node:assert/strict";
import { wordCount } from "../src/count.js";

// The visible suite. It covers the plain cases only; the held-out judge grades the edges.
test("counts words separated by single spaces", () => {
  assert.equal(wordCount("one two three"), 3);
});

test("a single word counts once", () => {
  assert.equal(wordCount("one"), 1);
});
