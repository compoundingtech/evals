# first-run — onboarding cell

**Discriminates:** consume public personas SHA-pinned + run first-run interview -> a private cos repo

**Capabilities required:** `st,git,network`  ·  run `bin/st-evals preflight` to confirm your setup supports this cell.

## Run it

`fixture/run-real-path.sh` is **self-isolating** — it creates its own scratch network root at
`$SANDBOX/st-root` and drives every CLI call with an explicit `ST_ROOT` + a clean `ST_AGENT`
(`env -u COORD_IDENTITY`), so nothing touches your live network. It needs **network once** (gate P0) to
clone the public `personas` repo pinned to a fixed SHA (read-only); everything after is offline. No
external `ST_ROOT` / `ST_HOOKS_DIR` / `PERSONAS_DIR` required (this is a Layer-1 CLI onboarding walk, not
a persona-team launch).
Then: `fixture/run-real-path.sh [SANDBOX]` — self-asserting; exit 0 = all gates PASS.

## Grading

- **Held-out acceptance** — see `task.toml` `[grader]`: an independent check the team never sees, so the result can not be gamed by editing a unit test.
- **Isolation is a hard PASS/FAIL gate:** every agent changes only the module/repo it owns; all coordination flows through the message bus. A non-owner change fails the run outright.

See `task.toml` for the full spec and [`../../framework.md`](../../framework.md) for the runner, axes, and grading model.
