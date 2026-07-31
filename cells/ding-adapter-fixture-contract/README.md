# ding-adapter-fixture-contract

Hermetic, model-free contract inventory for the optional DING activity-lease
matrix tracked by [evals#57](https://github.com/compoundingtech/evals/issues/57).

This cell validates only inputs that are safe to establish before the product
seams exist:

- nine shared, synthetic ASCII screen diagnostics;
- exact content hashes and provenance metadata;
- symmetric, explicitly blocked activity-event and post-turn-hook fixture
  slots for the two maintained provider adapters;
- matched A/B outcome and generic conditional-send race inventories; and
- the external dependency/evidence ledger, including exact runnable-draft PTY
  heads and the still-blocked adapter/core seams.

The screen text and requested terminal diagnostics are never activity
authority. No provider event payload or adapter interface is guessed here.
The exact PTY activity and guarded-send product surfaces are now exercised by
`ding-pty-activity-lease` and `ding-pty-guarded-send` against stacked draft head
`743ceb796a41a3282e31382575bff0d0e3826d59`, which contains activity head
`46c71d31c0d6daee43adf568061b2b84a65ae8c0`. Those runs are local exact-source
experiment evidence, not release artifacts. Product-dependent configured-DING
routing remains blocked until st2 and provider adapter seams exist.

The intended opt-in shape is an external adapter command selected by DING
through a generic protocol. Provider commands may differ, but core st2 and the
shared eval judge must not branch on provider identity. Exact selection syntax,
payloads, composer evidence, and hook output contracts remain blocked on
st2#111 plus immutable provider adapter fixtures.

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

The two PTY cells additionally require `EVALS_PTY_PR133_ROOT` to point to a
clean exact-head checkout after `npm ci && npm run build`. They verify the Git
head, activity-base ancestry, package-lock hash, and runtime artifact hashes in
their receipts.
