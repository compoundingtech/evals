# adopt-only-migration

**Type:** st2 / live-migration lifecycle · **Runtime dependency:** implemented
by merged [compoundingtech/st2#99](https://github.com/compoundingtech/st2/pull/99),
which closed [compoundingtech/st2#98](https://github.com/compoundingtech/st2/issues/98),
and tracked in evals by
[compoundingtech/evals#52](https://github.com/compoundingtech/evals/issues/52).

**Capabilities required:** `st2,pty,jq`. No model and no bus. Every declaration,
process, PTY record, state file, log, and receipt is synthetic and rooted below
the eval-owned catalog.

**Discriminates:** can an operator publish a declaration that adopts one
already-live process generation without granting authority to create, collect,
or replace it? An absent task and a later-dead adopted task must both remain
held until the declaration explicitly transitions to ordinary service
lifecycle.

## What it proves

- **Live adoption:** a pre-existing PTY is adopted with the same daemon and
  child process generation.
- **Absent hold:** an absent adopt-only task never executes its declared launch
  command.
- **Exited hold:** once the adopted generation exits, reconciliation retains
  its backend record and does not cold-launch a successor.
- **Explicit replacement:** removing the adopt-only lifecycle changes the
  desired contract; ordinary reconciliation may then collect and replace the
  exited generation.
- **Mutation-valid control:** an ordinary absent service task launches on the
  first pass, proving the launch substrate is real.
- **Isolation and cleanup:** the cell uses only its temporary catalog and PTY
  root and leaves no live synthetic processes.

## Run it

```sh
st2 eval ./cells/adopt-only-migration/
```

The current cell passes 7/7 against merged st2
`c6846f6239329f0803142afc06c15a07b93937c1`. Historically, it was intentionally
RED before #98/#99 because the runtime treated `lifecycle` as inert metadata;
that pre-implementation result is no longer the current shipping state.

Immutable pre-reap generation receipts remain the distinct design and
acceptance surface in
[compoundingtech/st2#40](https://github.com/compoundingtech/st2/issues/40).
This cell does not freeze a receipt path or schema ahead of that design.
