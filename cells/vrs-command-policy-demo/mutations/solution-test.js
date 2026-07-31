import assert from "node:assert/strict";
import test from "node:test";

import {
  buildWorkerTask,
  firstCommandArgv,
  quoteShellWord,
  validateCatalog,
} from "../src/index.js";

test("shell data parser preserves quoted bytes and stops at a boundary", () => {
  const value = `/srv/O'Brien builds`;
  assert.deepEqual(
    firstCommandArgv(`orbit worker --workspace ${quoteShellWord(value)}; echo ignored`),
    ["orbit", "worker", "--workspace", value],
  );
});

test("generated hostile workspace bytes pass the catalog validator", () => {
  for (const workspace of [
    "/srv/orbit/nightly build",
    `/srv/orbit/O'Brien`,
    "/srv/orbit/#release",
    String.raw`C:\orbit\build`,
  ]) {
    const task = buildWorkerTask({ id: "build", workspace });
    assert.equal(validateCatalog({ tasks: [task] }).ok, true);
  }
});

test("affected hand-authored tasks fail without a structured exact policy", () => {
  const base = {
    id: "build",
    kind: "worker",
    active: true,
    workspace: "/srv/build",
  };
  assert.equal(
    validateCatalog({ tasks: [{ ...base, command: "orbit worker" }] }).ok,
    false,
  );
  const wrong = JSON.stringify({
    workspaces: { "/srv/build/../build": { mode: "sandboxed" } },
  });
  assert.equal(
    validateCatalog({
      tasks: [{ ...base, command: `orbit worker --policy ${quoteShellWord(wrong)}` }],
    }).ok,
    false,
  );
});
