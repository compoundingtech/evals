# Network coverage — convoy · st · pty

These are **whole-network** evals, not smalltalk-only. This map shows, for each network component, which
cells put a capability of that component **under test** (its discriminator) — distinct from cells that
merely **use** it as plumbing (e.g. `convoy add` to spin up a team, `st launch` to spawn, `pty` for teardown).

**Headline:** convoy and st are both well-covered as subjects; pty is covered on durability/isolation but
thin on its direct verb surface. Two convoy gaps are tracked below.

## CONVOY — capabilities under test

| convoy capability | cells (subject) | coverage |
|---|---|---|
| `init` (layout + narration) | convoy-init-structure, convoy-init-narration | ✅ strong |
| `add` / compose (overlay, config-load, global+project skills, zero-pollution) | convoy-add-structure, clean-compose, compose-config-load, compose-global-skill, skill-inheritance, weird-git-setup | ✅ strong |
| `doctor` (pre-init UX, structure-proof, can-work self-test, abort/teardown) | convoy-doctor-preinit, convoy-doctor-structure, convoy-doctor-canwork, convoy-doctor-teardown | ✅ strong |
| `doctor` on a **foreign box** (false-negative class) | convoy-doctor-foreign-box | ✅ (the Johannes false-negative regression guard, #77 + #78) |
| `up` — hosting + respawn | convoy-network (capstone), crash-ding | ✅ |
| worktree / megarepo | convoy-worktree-cutting, weird-git-setup | ✅ |
| `reload` (restore path) | restorability, restorability-codex | ✅ |
| **job-lifecycle** (submit / run / status / complete) | convoy-job-lifecycle | 🔨 building (extends to the one-shot-agent job type) |
| `down` | indirect via convoy-doctor-teardown's abort trap | ⚠️ thin (no direct convoy-down cell) |

## ST (bus) — capabilities under test

| st capability | cells (subject) | coverage |
|---|---|---|
| messaging (send / reply / threading / archive) | ding-reply, inbox-hygiene, ding-mode, bootstrap-network | ✅ strong |
| ding / no-MCP sidecar (`[DING]`) | ding-mode, ding-reply, crash-ding | ✅ |
| hooks (SessionStart rehydrate) | hook-integrity (hook FIRES, not just configured), restorability(+codex) | ✅ |
| context (now.md read / write / append) | hook-integrity, restorability(+codex) | ✅ |
| `st launch` session resume (`--resume` / `--fresh`) | resumability | ✅ |
| status / agents discovery | bootstrap-network | ⚠️ thin |
| `st resource` | — none as subject — | ⚠️ minor gap (operational) |

## PTY (sessions) — capabilities under test

| pty capability | cells (subject) | coverage |
|---|---|---|
| spawn (session create) | implicit plumbing in every team cell (st launch / convoy add) | ✅ implicit |
| restart / cold-restart | restart-continuity, restorability | ✅ |
| session resume (pinned `--resume`) | resumability | ✅ |
| session death detection | crash-ding, convoy-doctor-teardown | ✅ |
| per-network `PTY_ROOT` isolation | two-networks-coexist | ✅ |
| **peek / send / write** (inspect live output / inject input) | tui-build consumes `pty peek` as content; two-networks refuses cross-net peek/send | ⚠️ not positively graded |

## Open gaps

1. **convoy job-lifecycle — HIGH, 🔨 building (`convoy-job-lifecycle`).** Zero cells touch `convoy job`
   (submit → run → status → complete). Built to extend to the incoming one-shot-agent job type.
2. **pty peek / send / write — MEDIUM.** Exercised only as plumbing (tui-build reads `pty peek` for content)
   or as an isolation-negative (two-networks asserts cross-network peek/send is refused). No cell asserts
   "peek returns the session's real output" or "send injects input the session acts on" as a positive
   capability. A `pty peek`/`pty send` round-trip cell would close it.
4. **convoy `down` lifecycle — LOW/MED.** Only covered incidentally via doctor-teardown's abort path; no
   direct "convoy down cleanly stops + reaps a running network" cell.
5. **st `resource` + status/agents discovery — LOW.** Thin/plumbing-only; no dedicated subject cell.

## Coverage math (subject-under-test)

- **convoy:** ~19 cells put a convoy capability under test — the strongest surface.
- **st:** ~11 cells as subject (messaging, ding, hooks, context, launch-resume).
- **pty:** ~7 cells as subject (restart, resume, death-detect, isolation, + spawn implicit).
- The remaining cells are **SDLC/task** cells (debug, review, migrate, test, feature, incident, audit,
  design, docs, rename, greenfield, standup, license-loop, onboarding) where convoy/st/pty are plumbing and
  the subject is a software-engineering task run over the network — the "it's the system, not the model" axis.
