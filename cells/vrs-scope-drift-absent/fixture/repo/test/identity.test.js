import assert from "node:assert/strict";
import test from "node:test";

import { createAgent, parseIdentity } from "../src/identity.js";

test("creates an immutable agent identity", () => {
  const identity = createAgent({ id: "build-1", displayName: "Builder" });
  assert.deepEqual(identity, {
    kind: "agent",
    id: "build-1",
    displayName: "Builder",
  });
  assert.equal(Object.isFrozen(identity), true);
});

test("parses the current agent identity form", () => {
  assert.deepEqual(parseIdentity("agent:worker-2"), {
    kind: "agent",
    id: "worker-2",
  });
});
