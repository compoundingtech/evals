# license-mit — license cell

**Discriminates:** delegate->execute->verify->confirm loop + isolation (matrix-capable)

**Capabilities required:** `claude,st,pty,git`  ·  run `bin/evals preflight` to confirm your setup supports this cell.

## Run it

The team is launched via the real `st launch` (the same command a user runs). `fixture/spin.sh` is
**self-isolating** — it creates and exports its own scratch bus root at `$SB/st-root`, so nothing touches
your live network; the st-launched agents inherit that root. You only need `PERSONAS_DIR` (a checkout of
the public personas repo — `bin/ensure-personas.sh` clones it pinned; the runner sets it for you). No
external `ST_ROOT` / `ST_HOOKS_DIR` required.

Run it: `fixture/spin.sh` (auto-materializes the sandbox if absent), or `bin/evals run license-mit`.
Tear down after grading with `bin/evals teardown <SB>`.

**Default = Claude-only** (Claude supervisor + Claude worker) — the most reliable from-scratch run, matching
this cell's declared caps. This is the **matrix cell**, so the same task/world also runs cross-family: use
`fixture/configure-codex-agent.sh` (Codex worker + ding wake sidecar) or `fixture/configure-glm-agent.sh`
(GLM via the Claude-Code harness) to swap a seat's family. (Codex-native end-to-end lives in the separate
`license-mit-codex` cell.)

## Grading

- **`fixture/grade.sh [SANDBOX]`** — mechanizes the ground-truth checks once the loop closes; never trusts a self-report. It reads only git metadata, the committed license text, and the smalltalk bus files, so a PASS means the loop really happened. Run it after the run, then tear down with `bin/evals teardown <SANDBOX>`.
- **Held-out acceptance** — see `task.toml` `[grader]`: an independent check the team never sees, so the result can not be gamed by editing a unit test.
- **Isolation is a hard PASS/FAIL gate:** every agent changes only the module/repo it owns; all coordination flows through the message bus. A non-owner change fails the run outright. Note: the worker repo's git identity is *pinned* to the worker, so git-author alone can't catch a "supervisor did it itself" violation — the honest proxy is structural (the supervisor owns no repo) **plus** coordination-visibility (a completed change with no delegate→report thread is the out-of-band signature). `grade.sh` encodes exactly that.

See `task.toml` for the full spec and [`../../framework.md`](../../framework.md) for the runner, axes, and grading model.
