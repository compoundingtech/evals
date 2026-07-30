# ding-adapter-fixture-contract

Hermetic, model-free scaffold for the optional DING activity-lease matrix tracked
by [evals#57](https://github.com/compoundingtech/evals/issues/57).

This cell validates only inputs that are safe to establish before the product
seams exist:

- nine shared, synthetic ASCII screen diagnostics;
- exact content hashes and provenance metadata;
- symmetric, explicitly blocked activity-event and post-turn-hook fixture
  slots for the two maintained provider adapters;
- matched A/B outcome and generic conditional-send race inventories; and
- the external dependency/evidence ledger.

The screen text and requested terminal diagnostics are never activity
authority. No provider event payload or adapter interface is guessed here.
Product-dependent routing assertions remain blocked until exact PTY and st2
source commits plus immutable, owner-reviewed provider fixtures are available.

The intended opt-in shape is an external adapter command selected by DING
through a generic protocol. Provider commands may differ, but core st2 and the
shared eval judge must not branch on provider identity. Exact selection syntax,
payloads, and hook output contracts remain blocked on st2#111.

The A/B inventory freezes the intended comparison without pretending it can
execute unfinished behavior. The conditional-send inventory names races and
outcomes only: a provider adapter must establish fresh idle plus an empty
composer, while PTY must atomically reject a DING candidate if its live
generation or generic I/O/snapshot revision changed. PTY does not classify
submit, newline, or human intent.

## Validation boundary

The scaffold cell, parser, semantic loader, fixture-reset, harness-exclusion,
preflight-reachability, generated-catalog, and full corpus gates are
model-free. The accepted successor runner is exact source
`c6846f6239329f0803142afc06c15a07b93937c1` with local-source Linux binary
SHA256 `2bba8d58be24250bc262f75f835ce2d780369add275774f3f2135c623d23d29c`.
Do not rebuild or substitute a different binary to claim the full corpus gate.
