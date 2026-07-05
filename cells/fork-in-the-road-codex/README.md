# fork-in-the-road-codex — design cell

**Discriminates:** the design panel Codex-native (cross-family)

**Capabilities required:** `codex,st,pty,git`  ·  run `bin/st-evals preflight` to confirm your setup supports this cell.

## Run it

Point `ST_ROOT` at a scratch network root, `ST_HOOKS_DIR` at your smalltalk `examples/claude-code/hooks`,
and `PERSONAS_DIR` at a checkout of the public personas repo (`bin/ensure-personas.sh` clones it pinned).
Then: `fixture/setup-sandbox.sh` to materialize the world, then `fixture/spin.sh` to launch the team.

## Grading

- **Held-out acceptance** — see `task.toml` `[grader]`: an independent check the team never sees, so the result can not be gamed by editing a unit test.
- **Isolation is a hard PASS/FAIL gate:** every agent changes only the module/repo it owns; all coordination flows through the message bus. A non-owner change fails the run outright.

See `task.toml` for the full spec and [`../../framework.md`](../../framework.md) for the runner, axes, and grading model.
