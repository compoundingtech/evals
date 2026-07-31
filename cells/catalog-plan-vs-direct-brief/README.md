# catalog-plan-vs-direct-brief

Model-free contract for the first experiment proposed by
[`st2 plans: today → dream`](https://gist.github.com/myobie/d5ecfac24cd3965e095a5031cd2e00cb/5c1d1427c0556d95d13890e5c5086cd85b25d994):
compare one realistic repository task delivered as a versioned local catalog
plan (A) with the same task delivered as an ordinary durable direct brief (B).

The frozen task, repository, tools, budgets, intent revisions, judges, and done
condition are identical. The two intent documents are byte-identical at each
revision. Both arms receive durable local input and use the same evaluator-owned
receipt fields, so direct planning remains a valid control rather than an
intentionally fragile baseline.

The deterministic fixture now runs both durable product paths:

- the seeded repository needs a real implementation and the arm-neutral
  reference solution passes public and held-out correctness tests;
- arm A recovers an initial and then revised catalog snapshot through exact
  `st2 plan show`/`inspect` calls;
- arm B receives the byte-identical revisions through real isolated
  `st2 message send` deliveries with `inReplyTo` lineage, then recovers them
  through `message ls`/`read`;
- both arms recover the same intent after cold state loss with their remote
  source offline, so cold resume, intent recovery, and steering are ties;
- neither read-only plan inspection nor direct-message delivery reports worker
  acceptance, so acceptance evidence is evaluator-owned in both arms and is
  also a tie;
- the plan adds native static validation and resolved provenance, but the
  current model-free result is `no-measured-advantage`; and
- no model or provider is launched.

Correctness, coordination traffic, token use, cost, and wall duration remain
unresolved live-run endpoints. The reference solution establishes a valid task
and neutral judge; it is not substituted for two agent executions.

Arm A uses the exact external `plan.kdl` and agent `plan-ref` contract from
[st2 draft PR #115](https://github.com/compoundingtech/st2/pull/115) at source
`2caa0d7f159c3c0d9c483bd63b2579d33f1986ff`, paired to the source gist at
revision `5c1d1427c0556d95d13890e5c5086cd85b25d994`. The accepted Linux
artifact SHA256 is
`83efb0564a3cd366404495936b1e29a30ea210b0e429dbfeb6901830b2c49c38`.
The fixture exercises only `plan validate`, `list`, `show`, and `inspect`, and
proves they do not alter the catalog.

Arm B uses the product's ordinary durable message store rather than a synthetic
thread sidecar. Neither arm receives a pre-authored acceptance receipt. The
experiment uses plain copied folders, requires no server, and sets
`casRequired` to false. The product experiment adds no current pointer,
execution, scheduling, steps, retries, progress claims, events,
reconciliation, or CAS. A provider-backed A/B remains a separate authorization
with an exact model, effort, budget, run order, spend ceiling, cleanup, and
rollback.
