# catalog-plan-vs-direct-brief

Model-free contract for the first experiment proposed by
[`st2 plans: today → dream`](https://gist.github.com/myobie/d5ecfac24cd3965e095a5031cd2e00cb):
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

Arm A reserves a catalog-local plan directory with immutable Markdown versions,
lineage metadata, and receipt space. Arm B reserves equivalent durable
message-thread metadata and receipt space. The scaffold deliberately does not
invent `plan.kdl` syntax or st2 runtime behavior. Those assertions remain
blocked until the st2 owner supplies one exact experimental source head,
supported interface, reproducible artifact hash, and focused receipts. A
paid/live A/B is a separate authorization with an exact model, effort, budget,
run order, and rollback.
