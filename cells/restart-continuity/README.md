# restart-continuity — durability cell

**Discriminates:** does a **cold-restarted** agent resume an ordered batch **losslessly** — every item done at least once (no skip), no corrupting redo — from the durable substrate alone? (held-out)

**Capabilities required:** `claude,st,pty,git,node`  ·  run `bin/st-evals preflight` to confirm your setup supports this cell.

## What it proves

The factory's premise is that agents survive restarts — context-saturation (HB-1), crashes, reboots,
`/clear`. This cell is the **eval form of that claim**: a specialist runs an ordered batch over a tiny
`ledger` service, and the runner **injects a cold restart** at a deterministic checkpoint (the item-2
commit). It grades whether the specialist picks up from durable ground truth (git log + `PROGRESS.md` +
`items.json` + the bus) without **skipping** a step, **corrupting** a redone one, drifting, or needing a
**human** to say what was already done.

Grade principle is **at-least-once** (duplicates don't matter; we want at-least-once, not at-most-once):
the hard gate is **NO ITEM SKIPPED**; a clean **duplicate** is tolerated; the real failure is a redo that
**corrupts**. The fixture's ops are **idempotent by design** (`register()` is last-wins; `items.json` is the
durable work-list) so a redo is genuinely harmless — that *is* the durability lesson.

## Run it

The team is launched via the real `st launch`. `fixture/spin.sh` is **self-isolating** — it creates and
exports its own scratch bus root at `$SB/st-root`, so nothing touches your live network; the st-launched
agents (and the cold relaunch) inherit that root by env inheritance. You only need `PERSONAS_DIR` (the
runner sets it for you via `bin/ensure-personas.sh`). No external `ST_ROOT` / `ST_HOOKS_DIR` required.

Run it: `fixture/spin.sh` (auto-materializes the sandbox if absent), or `bin/st-evals run restart-continuity`.
`spin.sh` launches `rc-dev` (owns `ledger`) + `rc-sup` (coordinate-only), seeds the hermetic kick, then
**backgrounds `fixture/restart-injector.sh`** — the scripted fault injection that cold-restarts `rc-dev`
after item 2 lands.

- Watch the injection: `tail -f $SB/.stev/injector.out`  ·  the batch: `git -C $SB/ledger log --oneline`
- Grade: `fixture/grade.sh <SB>`  ·  Tear down (zero-orphan, incl. the relaunched session): `bin/st-evals teardown <SB>`

## The cold restart (the one novel harness piece)

`restart-injector.sh` polls the ledger git log; on `>=2 feat: item` commits it records the restart event
(epoch + HEAD + done-items) to `$SB/.stev/restart.log`, then `RC_RESTART=1 configure-claude-agent.sh dev`:
`pty kill` the session, `rm .claude-session-id + pty.toml` (→ **fresh transcript** = a genuine cold boot),
and relaunch the **same** identity/persona/repo/bus under a new collision-proof session name (still
`role=agent`, ephemeral). Same identity ⇒ same git author ⇒ isolation attribution survives the restart.

## Grading

- **Held-out acceptance** — see `task.toml` `[grader]`: NO ITEM SKIPPED (every id done ≥1× with a working
  handler) + NO CORRUPTION (suite green, no duplicate dispatch keys) + RESUMED-not-front-loaded (item
  commits straddle the restart epoch). Duplicates are reported, not failed. Mechanized in `fixture/grade.sh`.
- **Autonomy is the headline:** rescues across the restart, target **0** — the injected restart is a
  scenario poke, not a rescue; a human telling the agent what was done *is* a rescue.
- **Isolation is a hard PASS/FAIL gate:** only `rc-dev` authors `ledger` commits (across the restart); the
  supervisor owns no repo. A non-owner change fails the run outright.

**v1 tests the substrate as-is** (no reconcile instruction in the personas) — both outcomes are publishable:
pass ⇒ the substrate is inherently recoverable; fail ⇒ a quantified gap that motivates a one-line
dev-practices addition (the v1→v2 iteration). See `task.toml` `[iteration]`.

See `task.toml` for the full spec and [`../../framework.md`](../../framework.md) for the runner, axes, and grading model.
