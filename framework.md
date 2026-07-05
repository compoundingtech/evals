# The st-evals framework

st-evals grades **agent teams**, not single agents. A team is a supervisor plus one or more
specialists, each running as a real agent on a real message bus. You seed one instruction; the team
self-organizes; a held-out check grades the result. The thing under test is the **system** — the
personas, the terminal-session harness, and the coordination bus — not any one model. That's why the
same cell runs across model families (Claude / Codex / GLM / mixed): if the result holds when you swap
the model, it was the system that produced it.

This document is the generic runner: the isolation gate, the hermetic kick, the grading axes, the
visible/held-out split, and the run lifecycle. Each `cells/<cell>/` is one scenario built on it.

---

## The six axes

Every team cell is graded on the same axes. **Isolation is a hard PASS/FAIL gate** and is checked
first — a violation fails the run regardless of how good the work is.

| Axis | What it measures |
|---|---|
| **isolation** *(hard gate)* | Each agent changed **only** the module/repo it owns; all coordination flowed through the bus. A non-owner change fails the run outright. |
| **task-success** | Did the team accomplish the actual task (suite green, correct result, deliverable produced)? |
| **quality** | Is the work good — minimal, idiomatic, root-caused not papered-over? Judged by a model from a **different family** than the one under test (a same-family judge inflates its own family's work). |
| **autonomy** | How many human rescues did the run need after the single kick? Zero = fully autonomous. (A *rescue* — the team was stuck — is distinct from a *wake nudge*, which is just the harness failing to deliver a message.) |
| **coordination** | Was the decomposition sound, the sequencing correct, the handoffs clean — and is it all visible in the message thread? |
| **cost** | Tokens + wall-clock for the whole tree. Measured from transcript token counts (not dollar estimates, which are plan- and rate-limit-blind). |

Onboarding cells (`bootstrap-network`, `first-run`) are graded **per-gate pass/fail** instead of on the
six axes — their deliverable is a severity-ranked **friction list**, not a solved task.

---

## Isolation — the hard gate

Isolation is the property the whole system rests on: an agent modifies only what it owns, and everything
else happens by message. It is enforced two ways, and both must hold:

- **By construction** — each specialist gets its own repo/worktree and *only* that. A coordinate-only
  supervisor owns **no** repo (its working directory is not a git repo, so it *cannot* commit) — structural
  isolation you can't accidentally violate.
- **By attribution** — after the run, every change is attributed to the owning agent (distinct git author
  per agent; the changed-path set per owner). A change to a module by a non-owner **fails the run**.

The proof lives in two places: git metadata (who authored what) and the message thread (the cross-agent
coordination must be *visible* — a consistent multi-repo change with no coordinating messages means
out-of-band coordination, which is itself a finding).

---

## The hermetic kick

A cell's team receives exactly **one** input: a frozen message seeded into the supervisor's inbox before
launch (the `kick-*.md` / the runner's seed step). No human prompts anyone once the run starts. On boot,
the supervisor drains its inbox, finds the kick, and the cascade self-starts. This makes a run
**reproducible** (the input is a file, not a live conversation) and makes the autonomy axis honest (every
later human touch is a countable rescue).

Everything the team needs to *emerge* — the decomposition, the delegation, the verification — must come
from the personas, not from the kick. A kick that over-specifies the solution isn't testing the system.

---

## Visible tests vs held-out acceptance

Every gradeable cell splits its checks:

- **Visible tests** — the suite the team can see and run (`npm test`, the cell's own tests). Table stakes;
  the team is expected to keep them green.
- **Held-out acceptance** — an independent check the team **never sees**, run only at grade time. It's
  designed so a unit-test edit can't fake it. Examples in this suite:
  - *ghost-bug*: apply the team's new regression test to the **original buggy commit** — it must FAIL
    there, or the "regression test" is theater.
  - *incident-response*: an independent nearest-rank **correctness gate** — the returned values must be
    *correct*, not merely non-500 (catches a band-aid that stops the error but ships wrong numbers).
  - *docs*: a fresh **cold-reader** agent gets only the docs + the library as a black box and must produce
    the right answer from the docs alone.
  - *test-writing*: a **mutation score** — the team's tests must KILL planted mutants, not just cover lines.

The held-out check is what makes "the eval can't be gamed" real rather than a slogan.

---

## Run lifecycle

1. **Materialize** a hermetic world in a throwaway sandbox (`fixture/setup-sandbox.sh`), frozen at a base
   commit. The live system is never touched — the agents edit copies.
2. **Compose** each agent's persona = task-lane + boot ritual + BASE layers + role layer (see *Persona
   layers*), and **wire** it to the bus (`fixture/compose-persona.sh` + `fixture/configure-*-agent.sh`).
3. **Seed** the hermetic kick into the supervisor's inbox and **launch** (`fixture/spin.sh`), workers
   first, supervisor last.
4. **Observe** the coordination on the bus; the team runs to a self-declared done.
5. **Grade**: isolation attribution first (the gate), then the visible suite, then the held-out
   acceptance, then quality (cross-family judge), then the rescue tally and cost.
6. **Preserve, then tear down**: keep the base commit + the run artifacts for grading; then neutralize
   and remove the ephemeral agents (they must never linger as zombies).

---

## Persona layers

An agent's persona is composed, not monolithic — base → role → task:

- **BASE** — shared by every coding agent: development practices + the known-harness-bugs it must work
  around. Sourced from the public `personas` repo, **SHA-pinned** (reproducibility = the pin).
- **ROLE** — `manager.md` / `technical-manager.md` (a coordinate-only supervisor) or `specialist.md` (an
  owner of one module). Also from the pinned personas.
- **TASK-LANE** — the per-cell wrapper the fixture writes: who you are, what you own, the hard isolation
  rules, and the boot ritual (set status → drain inbox → act). This is the only cell-specific layer.

Run `bin/ensure-personas.sh` to clone the personas repo at the pin; cells read their role files from it.

---

## Capability gating

Not every setup can run every cell. `bin/preflight.sh` detects installed tools (claude, codex,
ollama+GLM, git, gh, node, and the `st`/`coord` bus) and reports the **runnable subset**: a cell runs
only if *every* capability it needs is present. **Cross-family judging** (a quality judge from a different
family than the subject) is offered only when **≥2 model families** are installed — so the judge question
self-resolves: it simply doesn't run without two families.

`bin/readiness.sh` is the first-boot smoke suite — it proves the essentials (the bus works, a supervisor
can spawn a specialist, messages round-trip) via the hermetic `bootstrap-network` cell before you invest
in a full run.

---

## Public / private split

This repo is the **public** cut. It ships the framework, the cells (fixtures + graders), and the runner —
all de-personalized. It deliberately does **not** ship graded run-history against any private network
(verdicts, agent names, and real context stay private). The scripted principals in the onboarding cells
(e.g. "Jordan Rivera") are fully **synthetic** — zero real identity data — which is exactly what the
`first-run` cell's no-leak gate proves: private data comes from the interview, never from the public repo,
and nothing leaks back.
