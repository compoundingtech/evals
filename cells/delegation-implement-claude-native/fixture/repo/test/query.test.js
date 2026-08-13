import test from "node:test";
import assert from "node:assert/strict";
import { query } from "../src/search/query.js";

const entries = [
  { id: 1, title: "Alpha note" },
  { id: 2, title: "Beta note" },
  { id: 3, title: "Gamma" },
];

test("query matches on title substrings", () => {
  assert.deepEqual(query(entries, "note").map((e) => e.id), [1, 2]);
});

test("query returns nothing for an empty term", () => {
  assert.deepEqual(query(entries, "   "), []);
});
