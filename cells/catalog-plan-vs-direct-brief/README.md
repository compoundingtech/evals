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

Arm A uses the exact Resource-linked external `plan.kdl` contract from
[st2 draft PR #115](https://github.com/compoundingtech/st2/pull/115) at source
`8a76b6e71355140e5b89cd9313fcfd88c82b5cad`, while retaining the experiment
shape from source gist revision
`5c1d1427c0556d95d13890e5c5086cd85b25d994`. A childless Agent Spec Resource
with `_tag="plan"` supplies only the agent-local role and source-relative file
link. The referenced `plan.kdl` owns the plan identity, owner, versions, and
intent truth. The comparison path keeps its external Markdown content, and one
focused second target proves the supported inline-intent form without changing
the A/B scenario.

The accepted Linux artifact SHA256 is
`214e08874720bc546d4adf7d7977e614237baf7989cc09f6932cd991f497a753`;
hosted Nix run
[30835684680](https://github.com/compoundingtech/st2/actions/runs/30835684680),
job `91760161352`, passed. The fixture exercises only `plan validate`, `list`,
`show`, and `inspect`, and proves they do not alter the catalog. Legacy
`plan-ref` and agent-owned inline plan truth are not used.

This plan model stores no content digest or history, so it cannot prove that an
earlier declaration, parent link, or content file stayed unchanged.

Arm B uses the product's ordinary durable message store rather than a synthetic
thread sidecar. Neither arm receives a pre-authored acceptance receipt. The
experiment uses plain copied folders, requires no server, and sets
`casRequired` to false. The product experiment adds no current pointer,
execution, scheduling, steps, retries, progress claims, events,
reconciliation, or CAS. A provider-backed A/B remains a separate authorization
with an exact model, effort, budget, run order, spend ceiling, cleanup, and
rollback.
