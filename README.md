# st-evals

**Isolation-gated, held-out-graded evals for agent _teams_.**

Most agent evals score one model on one task. st-evals scores a **team** — a supervisor plus
specialists, each a real agent on a real message bus — doing real software work: debugging, review,
incident response, migration, security audit, design, docs, tests, and more. You seed one instruction;
the team self-organizes; an independent check the team never sees grades the result.

The thing under test is the **system** — the personas, the terminal-session harness, and the
coordination bus — **not any one model**. Every scenario runs across model families (Claude / Codex /
GLM / mixed). If the result still holds when you swap the model, it was the system that produced it.

> **Two ideas do the heavy lifting.** *Isolation* is a hard pass/fail gate: each agent may change only
> the module it owns; everything else happens by message. *Held-out acceptance* is a check the team can't
> see and can't game — a regression test replayed against the original bug, a correctness gate independent
> of the team's own tests, a fresh reader who only gets the docs. Pass both, on real work, across
> families, and you've shown the system works.

---

## Quickstart

```sh
bin/st-evals preflight     # what you have installed → which cells you can run
bin/st-evals readiness     # first-boot smoke: bus works, agents spawn, messages round-trip
bin/st-evals list          # the cell catalogue
bin/st-evals run ghost-bug # run a cell end-to-end
```

**Requirements.** A POSIX shell, `git`, and the [`smalltalk`](https://github.com/myobie/smalltalk) bus
(`st`/`coord`) + the [`pty`](https://github.com/myobie/pty) session harness on your `PATH`. At least one
agent harness (`claude` and/or `codex`, or `ollama` + a GLM model). Node for the cells whose sample
services are JS. `preflight` tells you exactly what you have and what each cell needs — a cell runs only
if every capability it needs is present, and **cross-family judging** unlocks once you have ≥2 families.

**Environment a run may need** (each cell's README says which):

| Var | Meaning |
|---|---|
| `ST_ROOT` | a scratch network root (throwaway) |
| `ST_HOOKS_DIR` | your `<smalltalk>/examples/claude-code/hooks` |
| `PERSONAS_DIR` | a checkout of the public [`personas`](https://github.com/myobie/personas) repo — `bin/ensure-personas.sh` clones it pinned for you |

---

## How a cell works

Each `cells/<cell>/` is one scenario:

```
cells/<cell>/
  task.toml      # the spec: what it evaluates, the team shape, isolation rules, the grader
  README.md      # what it discriminates + how to run it
  fixture/       # setup-sandbox.sh (materialize the frozen world), compose-persona.sh,
                 # configure-*-agent.sh (wire an agent to the bus), kick-*.md (the one input),
                 # spin.sh (launch), grade.sh (mechanized ground-truth checks)
```

A run **materializes a hermetic sandbox** at a frozen base commit (the live system is never touched),
**composes** each agent's persona (base → role → task-lane, from the pinned personas), **seeds one frozen
kick** into the supervisor's inbox, and **launches**. The team runs to a self-declared done; then the
grader attributes every change (isolation first), runs the visible suite, and runs the **held-out**
acceptance the team never saw.

See [`framework.md`](framework.md) for the axes, the isolation gate, the visible/held-out split, and the
full run lifecycle.

---

## The catalogue

Ten SDLC work-types, plus onboarding and cross-family variants. Full table with discriminators and
capabilities in [`REGISTRY.md`](REGISTRY.md); the short version:

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
| `bootstrap-network`, `first-run` | onboarding | zero → a working, network-joined CoS; the no-leak public/private split |

`*-codex` variants run the same scenario Codex-native — the cross-family proof.

---

## Write your own cell

1. `cells.manifest` — add a row: `name | type | ship | caps | discriminator`.
2. `cells/<name>/fixture/setup-sandbox.sh` — materialize a small, **synthetic** world frozen at a base
   commit (no real repos/identities). Make the visible suite green.
3. `cells/<name>/fixture/kick-*.md` — the single frozen instruction the supervisor wakes to. Don't
   over-specify the solution; the system should have to *emerge* it.
4. `cells/<name>/fixture/grade.sh` — mechanize the ground-truth checks. Include a **held-out** check that
   a unit-test edit can't fake (replay against the base commit, an independent correctness gate, a
   cold-reader, a mutation score).
5. `cells/<name>/task.toml` + `README.md` — the spec + how to run it.

Keep the sandbox synthetic and the grader honest: it must accept *any* correct solution, not one canonical
diff, and it must still discriminate a bad solution from a good one (validate it on a deliberately-wrong
mock).

---

## Public / private

This is the public cut: the framework, the cells, and the runner — de-personalized, with a `check-no-pii`
grep-gate as the backstop. It does **not** ship graded run-history against any private network. Scripted
principals (e.g. "Jordan Rivera") are fully synthetic — the `first-run` cell exists partly to *prove* no
real data crosses the public/private line.

MIT licensed — see [`LICENSE`](LICENSE).
