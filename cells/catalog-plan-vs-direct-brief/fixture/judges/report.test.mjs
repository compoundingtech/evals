import assert from "node:assert/strict";
import test from "node:test";
import { pathToFileURL } from "node:url";

const candidate = process.env.CANDIDATE_REPORT;
if (!candidate) {
  throw new Error("CANDIDATE_REPORT is required");
}

const { parseJsonLines, summarize } = await import(pathToFileURL(candidate));

test("retains complete records without mutating caller input", () => {
  const records = [
    { run_id: "r1", cell: "zeta", result: "PASS", usage: { input: 10 } },
    { run_id: "r2", cell: "alpha", result: "FAIL", note: "first" },
    { run_id: "r3", cell: "zeta", result: "FAIL", usage: { input: 11 } },
    { run_id: "r4", cell: "alpha", result: "PASS", note: "accepted" },
  ];
  const original = structuredClone(records);

  assert.deepEqual(summarize(records), [
    {
      cell: "alpha",
      accepted_pass: {
        run_id: "r4",
        cell: "alpha",
        result: "PASS",
        note: "accepted",
      },
      last_run: {
        run_id: "r4",
        cell: "alpha",
        result: "PASS",
        note: "accepted",
      },
    },
    {
      cell: "zeta",
      accepted_pass: {
        run_id: "r1",
        cell: "zeta",
        result: "PASS",
        usage: { input: 10 },
      },
      last_run: {
        run_id: "r3",
        cell: "zeta",
        result: "FAIL",
        usage: { input: 11 },
      },
    },
  ]);
  assert.deepEqual(records, original);
});

test("rejects duplicate run ids in parsed and direct records", () => {
  const duplicateText = [
    '{"run_id":"same","cell":"alpha","result":"PASS"}',
    '{"run_id":"same","cell":"beta","result":"FAIL"}',
  ].join("\n");

  assert.throws(
    () => parseJsonLines(duplicateText),
    (error) =>
      error instanceof TypeError &&
      /duplicate/.test(error.message) &&
      /same/.test(error.message),
  );
  assert.throws(
    () =>
      summarize([
        { run_id: "same", cell: "alpha", result: "PASS" },
        { run_id: "same", cell: "alpha", result: "FAIL" },
      ]),
    (error) =>
      error instanceof TypeError &&
      /duplicate/.test(error.message) &&
      /same/.test(error.message),
  );
});

test("rejects unknown results and identifies the run", () => {
  assert.throws(
    () =>
      parseJsonLines(
        '{"run_id":"mystery-7","cell":"alpha","result":"CANCELLED"}',
      ),
    (error) =>
      error instanceof TypeError &&
      /unknown result/.test(error.message) &&
      /mystery-7/.test(error.message),
  );
});

test("reports malformed and structurally invalid input lines", () => {
  assert.throws(
    () => parseJsonLines('\n{"run_id":"ok","cell":"alpha","result":"PASS"}\n{'),
    (error) => error instanceof TypeError && /line 3/.test(error.message),
  );
  assert.throws(
    () => parseJsonLines('["not","an","object"]'),
    (error) => error instanceof TypeError && /line 1/.test(error.message),
  );
  assert.throws(
    () => parseJsonLines('{"run_id":"","cell":"alpha","result":"PASS"}'),
    (error) =>
      error instanceof TypeError &&
      /line 1/.test(error.message) &&
      /run_id/.test(error.message),
  );
});
