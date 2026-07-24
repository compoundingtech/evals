---
name: evals
description: Run isolation-gated, held-out-graded agent-team evals for the compoundingtech network (st2 + pty). Use when asked to run an eval cell, smoke-test that a network runtime is wired correctly, or add a new eval cell. Each cell is a self-contained folder run by `st2 eval ./cells/<cell>/`.
---

# evals — agent-team eval suite

`evals` runs **isolation-gated, held-out-graded** evals for agent *teams* on the compoundingtech network.
The thing under test is the **whole network** — **st2** (the unified runtime that *renders* seats,
*runs* the network, and carries the *message* bus — it replaces convoy + smalltalk) and **pty** (the
terminal-session harness) — not any one model. Each cell seeds one instruction, lets a real team
self-organize, then grades the result with a check the team never sees.

## Run it

Each cell is a **self-contained folder** — the whole eval is declared in one `<cell>.kdl`. The runner is
`st2 eval`:

```sh
st2 eval ./cells/<cell>/     # copy the fixture → boot the team + judges → deliver the kick →
                             # wait for the sup's confirmation → run the held-out judges → verdict
```

Every run is **isolated**: `st2 eval` materializes a throwaway **catalog** (`$CATALOG`) and points the
cell's scratch bus + pty roots inside it, so the run never touches your live network. The catalog is
reaped at the end (pass `--keep` to preserve it for inspection).

Run output ends in a machine-readable line — `SCORE: N PASS / M FAIL / K gating judges` then
`VERDICT: PASS|FAIL`. Some judges are `signal`-only (they print `[SIGNAL] …` and are **excluded** from the
score — informational, not gating); the verdict turns on the gating judges alone.

## Requirements

All on `PATH`:

- **st2** — the network runtime (render / run / message + `st2 eval`) — https://github.com/compoundingtech/st2
- **pty** — the terminal-session harness (`st2 pty` wraps it) — https://github.com/compoundingtech/pty
- `git`; `node` for cells whose sample services are JS
- at least one agent harness: `claude` and/or `codex`

**Cross-family judging** (a quality judge from a different model family than the subject) unlocks once ≥2
families are installed. `*-codex` cells run the same scenario Codex-native — the cross-family proof.

## Layout

A cell is a folder; the `.kdl` is the whole spec (no manifest, no registry — the folder is the truth):

```
cells/<cell>/
  <cell>.kdl     the whole eval: env{} (scratch roots under $CATALOG) · team{}/agent{} seats
                 (workspace · command · ding) · eval{ copy fixture · run{step} · message{} kick ·
                 max-timeout · supervise · judges{} }
  fixture/       the synthetic world st2 copies into $CATALOG at boot (repos, personas, seed files)
  task.md        the single frozen instruction delivered to the supervisor (the `message{}` kick)
  judges/*.sh    the held-out graders — run AFTER the team declares done, CWD = the cell folder, with
                 $CATALOG set; the team never sees them  (simple checks can inline `exec "…"` in the .kdl)
  README.md      what the cell discriminates + how to run it
```

Team-less deterministic cells (e.g. the `st2 up`/`doctor`/`pty` infra cells) skip `task.md` and drive
everything from `run{step}` + inline judges — no agents, pure ground-truth.

## Add a cell

1. `cells/<name>/<name>.kdl` — declare the whole eval. Point `env{}`'s `ST_ROOT`/`PTY_ROOT` inside
   `$CATALOG`; `copy "./fixture"`; set `max-timeout`; add `supervise` for a team cell.
2. `cells/<name>/fixture/` — materialize a small **synthetic** world (no real repos/identities). Anything
   that needs an absolute-path git topology is built in a `run{step "materialize"}` that runs **before**
   the team boots (a static copy can't preserve absolute gitdir pointers).
3. `cells/<name>/task.md` — the single frozen instruction the supervisor wakes to (the `message{}`
   content). Don't over-specify the solution; the system should have to *emerge* it.
4. `cells/<name>/judges/*.sh` — mechanize ground-truth checks, each a **held-out** check a unit-test edit
   can't fake (replay against the base commit, an independent correctness gate, a cold-reader, a mutation
   score). Judges `git grep` **tracked** files — never the working tree (it includes the gitignored persona
   overlay, whose task text can name the very thing you're grading for).
5. `cells/<name>/README.md` — the discriminator + how to run it.

Keep the fixture synthetic and the grader honest: it must accept *any* correct solution (not one canonical
diff) and still discriminate bad from good (validate it on a deliberately-wrong mock). Prove every PASS on
a real `st2 eval` run before you commit it — never eyeball a green.
