# evals

**Isolation-gated, held-out-graded evals for agent _teams_.**

Most agent evals score one model on one task. evals scores a **team** — a supervisor plus
specialists, each a real agent on a real message bus — doing real software work: debugging, review,
incident response, migration, security audit, design, docs, tests, and more. You seed one instruction;
the team self-organizes; an independent check the team never sees grades the result.

The thing under test is the **whole network** — **st2** (the unified runtime that *renders* agents into
repos, *runs* the network, and carries the *message* bus — it replaces convoy + smalltalk) and **pty**
(the terminal-session harness) — plus the personas, and **not any one model**. Every scenario runs across
model families (Claude / Codex / mixed). If the result still holds when you swap the model, it was the
system that produced it.

> **Two ideas do the heavy lifting.** *Isolation* is a hard pass/fail gate: each agent may change only
> the module it owns; everything else happens by message. *Held-out acceptance* is a check the team can't
> see and can't game — a regression test replayed against the original bug, a correctness gate independent
> of the team's own tests, a fresh reader who only gets the docs. Pass both, on real work, across
> families, and you've shown the system works.

---

## Adopt it — standalone, end to end

evals is self-contained: clone this repo, put `st2` on your `PATH`, run a cell. Each cell is a
**self-contained folder**, and the runner is `st2 eval`:

```sh
git clone https://github.com/compoundingtech/evals
cd evals

st2 eval ./cells/ghost-bug/     # run a cell end-to-end
st2 eval ./cells/ghost-bug/ --keep   # …and preserve the throwaway catalog for inspection
```

`st2 eval` copies the cell's fixture into a throwaway **catalog** (`$CATALOG`), points the scratch bus +
pty roots inside it, boots the team and the held-out judges, delivers the one kick, waits for the
supervisor's confirmation, then runs the judges → **verdict**. Every run is isolated; the live network is
never touched, and the catalog is reaped at the end. Output ends in `SCORE: N PASS / M FAIL / K gating
judges` and `VERDICT: PASS|FAIL`.

**Requirements** (all on your `PATH`):

- [`st2`](https://github.com/compoundingtech/st2) — the network runtime: render / run / message + `st2 eval`
- [`pty`](https://github.com/compoundingtech/pty) — the terminal-session harness (`st2 pty` wraps it)
- `git`, and `node` for cells whose sample services are JS
- at least one agent harness: `claude` and/or `codex`

**Cross-family judging** — a quality judge from a different model family than the subject — unlocks once
you have ≥2 families installed. The `*-codex` cells run the same scenario Codex-native.

---

## How a cell works

Each `cells/<cell>/` is one scenario, declared end-to-end in a single `.kdl`:

```
cells/<cell>/
  <cell>.kdl   the whole eval: env{} (scratch roots under $CATALOG) · team{}/agent{} seats
               (workspace · command · ding) · eval{ copy fixture · run{step} · message{} kick ·
               max-timeout · supervise · judges{} }
  fixture/     the synthetic world st2 copies into $CATALOG at boot (repos, personas, seed files)
  task.md      the single frozen instruction delivered to the supervisor (the message{} kick)
  judges/*.sh  the held-out graders — run after the team declares done; the team never sees them
  README.md    what the cell discriminates + how to run it
```

`st2 eval` **materializes a hermetic catalog** at a frozen base commit (the live system is never touched),
delivers the one frozen kick to the supervisor, and lets the team run to a self-declared done. Then the
graders attribute every change (isolation first), and run the **held-out** acceptance the team never saw.
Anything that needs an absolute-path git topology is built in a `run{step "materialize"}` that runs
*before* the team boots. Team-less deterministic cells (the `st2 up`/`doctor`/`pty` infra cells) skip
`task.md` and drive everything from `run{step}` + inline judges — pure ground-truth, no agents.

---

## The catalogue

SDLC work-types, whole-network infrastructure cells (**st2** · **pty**), and cross-family variants. Each
cell's own `README.md` carries its full discriminator and held-out acceptance; the short version:

| Cell | Work-type | The discriminator (what a weak team fails) |
|---|---|---|
| `ghost-bug` | debug | root-cause the aliasing bug + add a regression test that FAILS on the base commit |
| `poisoned-pr` | review | catch the planted security hole CI misses; request-changes, don't rubber-stamp |
| `incident-response` | incident | the ROOT fix, not a band-aid that stops the 500 but ships wrong numbers |
| `migration` | dependency-bump | migrate every call site + don't silently drop removed APIs; tests not weakened |
| `security-audit` | audit | trace input→sink across the repo + dismiss the red-herrings (signal vs noise) |
| `feature-fit` | feature | add a feature *indistinguishable* from the existing code, not a bolt-on |
| `docs` | docs | a doc a **cold reader** can act on correctly with no other context |
| `test-writing` | tests | tests that **kill mutants** (mutation score), not coverage theater |
| `fork-in-the-road` | design | N genuinely distinct approaches → real debate → a justified, escalated call |
| `license-mit` | team loop | the smallest delegate→execute→verify→confirm loop with isolation held (the **matrix** cell) |
| `hook-integrity`, `st2-network`, `st2-doctor-structure` | infra | the runtime itself: a hook that *fires* (not just configured), `st2 up` hosting a net, `st2 doctor` failing closed |

`*-codex` variants (`ghost-bug`, `poisoned-pr`, `fork-in-the-road`, `license-mit`) run the same scenario
Codex-native — the cross-family proof.

---

## Write your own cell

1. `cells/<name>/<name>.kdl` — declare the whole eval: `env{}` with `ST_ROOT`/`PTY_ROOT` inside
   `$CATALOG`, `copy "./fixture"`, a `max-timeout`, `supervise` for a team cell, and the `judges{}`.
2. `cells/<name>/fixture/` — materialize a small, **synthetic** world (no real repos/identities). Build
   any absolute-path git topology in a `run{step "materialize"}` (a static copy can't preserve it).
3. `cells/<name>/task.md` — the single frozen instruction the supervisor wakes to (the `message{}`
   content). Don't over-specify the solution; the system should have to *emerge* it.
4. `cells/<name>/judges/*.sh` — mechanize the ground-truth checks. Include a **held-out** check a
   unit-test edit can't fake (replay against the base commit, an independent correctness gate, a
   cold-reader, a mutation score). Judges `git grep` **tracked** files — never the working tree.
5. `cells/<name>/README.md` — the discriminator + how to run it.

Keep the fixture synthetic and the grader honest: it must accept *any* correct solution, not one canonical
diff, and it must still discriminate a bad solution from a good one (validate it on a deliberately-wrong
mock). Prove every PASS on a real `st2 eval` run before you commit — never eyeball a green.

---

## Public / private

This is the public cut: the framework, the cells, and the folder-eval spec — de-personalized, with a
`check-no-pii` grep-gate as the backstop. It does **not** ship graded run-history against any private
network. Scripted principals are fully synthetic — no real data crosses the public/private line.

MIT licensed — see [`LICENSE`](LICENSE).
