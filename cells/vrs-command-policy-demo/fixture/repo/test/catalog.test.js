import assert from "node:assert/strict";
import test from "node:test";

import {
  buildWorkerTask,
  firstCommandArgv,
  quoteShellWord,
  validateCatalog,
} from "../src/index.js";

test("shell data parser preserves quoted bytes and stops at a command boundary", () => {
  const value = `/srv/O'Brien builds`;
  assert.deepEqual(
    firstCommandArgv(`orbit worker --workspace ${quoteShellWord(value)}; echo ignored`),
    ["orbit", "worker", "--workspace", value],
  );
});

test("worker generator returns the stable catalog shape", () => {
  assert.deepEqual(buildWorkerTask({ id: "build", workspace: "/srv/build" }), {
    id: "build",
    kind: "worker",
    active: true,
    workspace: "/srv/build",
    command: "exec orbit worker --workspace /srv/build",
  });
});

test("catalog validator reports ordinary structural errors", () => {
  assert.deepEqual(validateCatalog({ tasks: [] }), { ok: true, errors: [] });
  const invalid = validateCatalog({ tasks: [{ id: "", command: "" }] });
  assert.equal(invalid.ok, false);
  assert.equal(invalid.errors.length, 2);
});
