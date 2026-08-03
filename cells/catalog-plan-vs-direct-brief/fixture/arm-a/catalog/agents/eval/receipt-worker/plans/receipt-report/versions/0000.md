# Receipt report: latest accepted pass and last run

Revision: `0000`

## Goal

Implement the report core in `src/report.mjs`. The report must retain the most
recent accepted `PASS` for each cell independently from that cell's last run,
which may be a failure.

## Scope and owner

You own the frozen `receipt-report` repository for this task. Change only
`src/report.mjs`.

## Required behavior

- `parseJsonLines(text)` ignores blank lines and returns records in input order.
- Malformed JSON, non-object JSON, or a record missing non-empty `run_id`,
  `cell`, or `result` fields throws a `TypeError` that identifies the input line.
- `summarize(records)` returns one row per cell, sorted by cell name.
- Each row is `{ cell, accepted_pass, last_run }`.
- `accepted_pass` is the complete most recent `PASS` record for the cell, or
  `null` when the cell has no pass.
- `last_run` is the complete last record for the cell.
- Neither exported function mutates caller-owned records.

## Invariants and allowed actions

Use only the repository's existing Node, Bash, and Git tools. Do not access the
network or add dependencies. Do not weaken or replace tests. No action outside
the frozen repository is authorized.

## Evidence and done condition

Run `npm test`. Completion additionally requires the evaluator's held-out tests
to pass and a diff containing only `src/report.mjs`.
