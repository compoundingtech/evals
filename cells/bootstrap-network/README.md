# bootstrap-network — onboarding cell

**Discriminates:** zero-to-network: init + CoS boots + spawn a specialist + message end-to-end

**Capabilities required:** `st,pty,git`  ·  run `bin/st-evals preflight` to confirm your setup supports this cell.

## Run it

`fixture/run.sh` is **self-isolating** — it creates its own scratch network root at `$SB/st-root` and pins
every CLI call to it, so nothing touches your live network; no external `ST_ROOT` / `ST_HOOKS_DIR` /
`PERSONAS_DIR` are required (this is a hermetic, offline CLI onboarding walk, not a persona-team launch).

Run it: `fixture/run.sh [SANDBOX]` (or `bin/st-evals run bootstrap-network`) — self-asserting; exit 0 =
all 4 gates PASS. The deliverable is the printed friction list.

## Grading

- **Held-out acceptance** — see `task.toml` `[grader]`: an independent check the team never sees, so the result can not be gamed by editing a unit test.
- **Isolation is a hard PASS/FAIL gate:** every agent changes only the module/repo it owns; all coordination flows through the message bus. A non-owner change fails the run outright.

See `task.toml` for the full spec and [`../../framework.md`](../../framework.md) for the runner, axes, and grading model.
