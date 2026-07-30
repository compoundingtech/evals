import assert from "node:assert/strict";
import test from "node:test";

import { parseJsonLines, summarize } from "../src/report.mjs";

test("reports the latest accepted pass separately from the last run", () => {
  const records = parseJsonLines(`
{"run_id":"r1","cell":"alpha","result":"PASS","score":"2/2"}
{"run_id":"r2","cell":"alpha","result":"FAIL","score":"1/2"}
{"run_id":"r3","cell":"beta","result":"FAIL","score":"0/1"}
`);

  assert.deepEqual(summarize(records), [
    {
      cell: "alpha",
      accepted_pass: {
        run_id: "r1",
        cell: "alpha",
        result: "PASS",
        score: "2/2",
      },
      last_run: {
        run_id: "r2",
        cell: "alpha",
        result: "FAIL",
        score: "1/2",
      },
    },
    {
      cell: "beta",
      accepted_pass: null,
      last_run: {
        run_id: "r3",
        cell: "beta",
        result: "FAIL",
        score: "0/1",
      },
    },
  ]);
});

test("ignores blank lines and sorts cells", () => {
  const records = parseJsonLines(`

{"run_id":"r1","cell":"zeta","result":"PASS"}

{"run_id":"r2","cell":"alpha","result":"PASS"}
`);

  assert.deepEqual(
    summarize(records).map(({ cell }) => cell),
    ["alpha", "zeta"],
  );
});
