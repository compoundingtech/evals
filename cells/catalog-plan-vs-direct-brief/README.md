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
`60d48bae5b7ac3a83c8d2c3324b61680bd6404dd`, paired to the source gist at
revision `5c1d1427c0556d95d13890e5c5086cd85b25d994`. The accepted Linux
artifact SHA256 is
`f3e935ee8e6c38b5ba29f0507b4639fe2212e3764b43e18967f6762a5962e48a`.
The fixture exercises only `plan validate`, `list`, `show`, and `inspect`, and
proves they do not alter the catalog.

This plan model stores no content digest or history, so it cannot prove that an
earlier declaration, parent link, or resource file stayed unchanged. The
correction executable is not byte-identical to predecessor source
`044964e4e07e3a656ccc1860bfff8517adf72c16`; its binary SHA256 was
`38a7fe4657e0583c34d13f73a9215e9f388e6cc2b87d6c9b9c70f07a9fce8f81`.
The correction changes plan terminology only. The test blob and this fixture's
JSON outputs for all four read-only commands remain byte-identical.

Arm B uses the product's ordinary durable message store rather than a synthetic
thread sidecar. Neither arm receives a pre-authored acceptance receipt. The
experiment uses plain copied folders, requires no server, and sets
`casRequired` to false. The product experiment adds no current pointer,
execution, scheduling, steps, retries, progress claims, events,
reconciliation, or CAS. A provider-backed A/B remains a separate authorization
with an exact model, effort, budget, run order, spend ceiling, cleanup, and
rollback.
