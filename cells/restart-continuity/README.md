# restart-continuity — durability cell

**Discriminates:** does a **cold-restarted** agent resume an ordered batch **losslessly** — every item done at least once (no skip), no corrupting redo — from the durable substrate alone? (held-out)

**Capabilities required:** `claude,st,pty,git,node`

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

## Run it (st2 folder-eval)

```sh
st2 eval ./cells/restart-continuity/
```

`restart-continuity.kdl` is the whole eval. It copies the pre-built world (`worker/_git`→`.git` on copy) and boots
a team: `rc.sup` (coordinate-only) + `rc.dev` (owns the `ledger` repo) + `rc.inj` (an eval-only fault-injector seat
— no bus voice). The kick goes to `rc.sup`; `rc.inj` cold-restarts `rc.dev` at the item-2 checkpoint (`pty kill`),
and the `supervise` directive respawns `rc.dev` FROM SPEC (cold, full env — no `--resume`). The cold-booted worker
must resume LOSSLESSLY from the durable substrate (git + `PROGRESS.md` + `items.json` + the bus). Four held-out
`judges/` (grade principle = at-least-once: no SKIP; a clean duplicate is tolerated). Hermetic catalog; nothing
touches your live network. Caps: `claude,st,pty,git,node`.

## The cold restart (the one novel harness piece)

The `rc.inj` seat (eval-only, no bus voice) polls the ledger git log; on the item-2 checkpoint commit it records
the restart event (epoch + HEAD + done-items) to `$CATALOG/.stev/restart.log`, then `pty kill`s `rc.dev`. The
`supervise` directive respawns `rc.dev` FROM SPEC — cold, full env, no `--resume` (⇒ **fresh transcript** = a
genuine cold boot). Same identity ⇒ same git author ⇒ isolation attribution survives the restart.

## Grading

- **Held-out judges (`judges/`):** NO ITEM SKIPPED (every id done ≥1× with a working handler) + NO CORRUPTION
  (suite green, no duplicate dispatch keys) + RESUMED-not-front-loaded (item commits straddle the restart epoch,
  read from `$CATALOG/.stev/restart.log`) + coordination + isolation. Duplicates are reported, not failed.
- **Autonomy is the headline:** rescues across the restart, target **0** — the injected restart is a
  scenario poke, not a rescue; a human telling the agent what was done *is* a rescue.
- **Isolation is a hard PASS/FAIL gate:** only `rc-dev` authors `ledger` commits (across the restart); the
  supervisor owns no repo. A non-owner change fails the run outright.

**v1 tests the substrate as-is** (no reconcile instruction in the personas) — both outcomes are publishable:
pass ⇒ the substrate is inherently recoverable; fail ⇒ a quantified gap that motivates a one-line
dev-practices addition (the v1→v2 iteration).

See `restart-continuity.kdl` + `judges/` for the full spec.
