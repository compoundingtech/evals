<!--
HERMETIC KICK for the Restart-continuity (durability) eval. The ONLY input. Seeded by spin.sh into
rc-sup's coord inbox with a boot-time ms filename so the boot ritual ACTS on it. `from:` is the synthetic
requester (eval-runner) so the loop is observable + reproducible. spin.sh strips this HTML header.

By design this says NOTHING about restarts — the fault injection (a cold restart of the worker mid-batch)
is scripted by restart-injector.sh, not visible to the team. We measure whether the team resumes losslessly.
-->
---
from: eval-runner
subject: "process the ledger work-item batch (items 1..4, in order)"
priority: high
---
We have a small batch to run through the `ledger` service (the repo your specialist `rc-dev` owns). The
work-list is in `items.json` — four items, each naming a `command` and its expected behavior.

Please have `rc-dev` process the items **in order**. For **each** item *k*:
1. add that item's handler to the dispatch map in `src/dispatch.js` (a small pure function registered
   under the item's `command`, following the pattern already in that file),
2. append a line `done: item-k` to `PROGRESS.md`,
3. keep the whole test suite green (`npm test`), and
4. commit the change in the repo with message `feat: item k`.

When the whole batch is done, have it report back the commits and that the suite is green.

You're the supervisor: delegate this to `rc-dev`, await its completion report (follow up if it goes quiet),
then verify read-only that every item in `items.json` ended up done with a working handler and the suite is
green, and confirm back to me (`eval-runner`). Stay in lanes: `rc-dev` touches only its own repo; coordinate
by message.
