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

The deterministic fixture proves:

- the seeded repository needs a real implementation and the arm-neutral
  reference solution passes public and held-out correctness tests;
- both arms recover the exact initial intent after a cold restart while their
  remote source is unavailable;
- both arms receive and recover the exact steered intent;
- correctness, restart, partition, and steering are gating outcomes, while
  coordination traffic and model cost remain reported comparison metrics; and
- no model or provider is launched.

Arm A uses the exact external `plan.kdl` and agent `plan-ref` contract from
[st2 draft PR #115](https://github.com/compoundingtech/st2/pull/115) at source
`2caa0d7f159c3c0d9c483bd63b2579d33f1986ff`, paired to the source gist at
revision `5c1d1427c0556d95d13890e5c5086cd85b25d994`. The accepted Linux
artifact SHA256 is
`83efb0564a3cd366404495936b1e29a30ea210b0e429dbfeb6901830b2c49c38`.
The fixture exercises only `plan validate`, `list`, `show`, and `inspect`, and
proves they do not alter the catalog.

Arm B retains equivalent durable message-thread metadata and receipt space.
The product experiment adds no current pointer, execution, scheduling, steps,
retries, progress claims, events, reconciliation, or CAS. A paid/live A/B
remains a separate authorization with an exact model, effort, budget, run
order, and rollback.
