# hook-integrity — current native hook materialization

This model-free cell proves the supported hand-authored `render {}` contract installs both accepted
harness overlays and native st2 hook configurations correctly.

It creates clean Claude and Codex Git workspaces, validates their catalog declarations, and runs:

```sh
st2 up --catalog "$CATALOG/net" --host evalhost --materialize-only
```

twice. Held-out judges require:

- Claude `SessionStart`, `PreCompact`, and `StopFailure`, targeting the three installed executable
  `claude-*` hooks;
- Codex `SessionStart`, `PreCompact`, and `Stop`, targeting the three installed executable `codex-*`
  hooks;
- the current Claude `.st2` rule loaders and the catalog-owned Codex `AGENTS.md`;
- byte-identical output after the second materialization; and
- two clean product worktrees, with overlay files excluded through `.git/info/exclude`.

The cell deliberately launches neither harness and does not claim that a model session fired a hook. Its
discriminator is the current supported native installation/materialization contract, not retired composition
behavior.

Run it explicitly with:

```sh
st2 eval ./cells/hook-integrity/
```
