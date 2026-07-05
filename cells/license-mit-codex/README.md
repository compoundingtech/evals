# license-mit-codex — license cell (full-Codex team)

**Discriminates:** the delegate→execute→verify→confirm loop Codex-native (cross-family)

**Capabilities required:** `codex,st,pty,git`  ·  run `bin/st-evals preflight` to confirm your setup supports this cell.

The single-family **Codex** point of the license-mit matrix: same task and world as the Claude and Mixed
runs (change a `widget` lib's license proprietary → MIT), so it sits as a clean, directly-comparable point.
The only variable is the composition — a full Codex team: `lmc-sup` (coordinate-only) + `lmc-worker`
(owns the widget repo). Confirms the smallest team loop works Codex-native, not only Claude/Mixed.

## Run it

Point `ST_ROOT` at a scratch network root and `PERSONAS_DIR` at a checkout of the public personas repo
(`bin/ensure-personas.sh` clones it pinned). Then: `fixture/setup-sandbox.sh` to materialize the world
(reuses the `license-mit` widget builder + composes both Codex `AGENTS.md`), then `fixture/spin.sh` to
launch the team. Codex wakes via a `ding` sidecar (not asyncRewake); the shared stev harness names and
tears down the pty sessions (`bin/st-evals teardown <SB>` after grading — zero orphans).

## Grading

- **Held-out acceptance** — see `task.toml` `[grader]` (inherits `license-mit`): an independent check the team never sees, so the result can not be gamed by editing a unit test.
- **Isolation is a hard PASS/FAIL gate:** every agent changes only the module/repo it owns; all coordination flows through the message bus. A non-owner change fails the run outright.

See `task.toml` for the full spec and [`../../framework.md`](../../framework.md) for the runner, axes, and grading model.
