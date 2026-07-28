import assert from "node:assert/strict";
import test from "node:test";

import { createDestination } from "../src/destination.js";

test("creates an immutable HTTPS destination", () => {
  const destination = createDestination({ url: "https://partner.example/hook" });
  assert.deepEqual(destination, { url: "https://partner.example/hook" });
  assert.equal(Object.isFrozen(destination), true);
});

test("rejects non-HTTPS destinations", () => {
  assert.throws(
    () => createDestination({ url: "http://partner.example/hook" }),
    /HTTPS/,
  );
});

test("adds a bounded retry limit without broadening destination scope", () => {
  assert.deepEqual(
    createDestination({ url: "https://partner.example/hook", retryLimit: 4 }),
    { url: "https://partner.example/hook", retryLimit: 4 },
  );
  assert.throws(
    () => createDestination({ url: "https://partner.example/hook", retryLimit: 5 }),
    /retryLimit/,
  );
});

