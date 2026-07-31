# targeted-reconcile-isolation

**Type:** st2 / reconciliation safety · **Ship:** guards
[compoundingtech/st2#29](https://github.com/compoundingtech/st2/issues/29)
and [compoundingtech/st2#50](https://github.com/compoundingtech/st2/pull/50).

**Capabilities required:** `st2,git`. No model, bus, or real PTY. The cell
prepends a recording `pty` shim and uses harmless terminal-free `true` tasks.

**Discriminates:** can an operator select one exact task without materializing
or launching any sibling, while the older agent-wide materialization selector
fails closed if it is mistakenly combined with one-shot reconciliation?

## What it proves

- `--task` is visible as the selected materialize/reconcile surface.
- `--once --agent` exits nonzero before `pty list` or workspace writes.
- `--materialize-only --agent` still materializes exactly one agent.
- `--once --task repro.one.work` performs one runner listing, materializes the
  owner, launches only its terminal-free task, and omits the sibling from both
  state and output.
- An unselected `--once` positive control reaches both synthetic siblings, so
  the isolation assertions would fail against the stale behavior.
- Catalog, workspace, runner log, exec state, and declared PTY root all live
  below the eval-owned temporary catalog.

## Run it

```sh
st2 eval ./cells/targeted-reconcile-isolation/
```
