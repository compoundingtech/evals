# Delegation parity — preregistered design

Date: 2026-08-12
Status: designed and model-free-gated before any paid execution. No arm has been run.

## Question

On real delegation work, are **st2-managed sub-agents worse than harness-native sub-agents**?

The fleet has already decided to delegate through canonical Agent Specs and to refuse harness-native spawn
tools inside managed launches. This tournament is the **regression check on that decision**, not a
re-litigation of it: it exists to notice if managed delegation ever becomes dramatically worse at real work
than the native fan-out it replaced. A native arm winning a task by a nose changes nothing; a native arm
finishing work the managed arm repeatedly cannot finish is the signal worth having.

## Non-goals

- **Not a fine-grained benchmark.** The endpoint is "not dramatically worse", stated below as an explicit
  falsification rule. No arm ranking, no per-token efficiency claim, no latency regression budget.
- **Not a new judging harness.** Every cell runs through `st2 eval` and the corpus's existing held-out judge
  contract. No new runner, ledger, or grading service is introduced. The only new gate is one model-free
  matching/oracle script, `bin/check-delegation-parity.sh`, wired into the existing free preflight.
- **Not a test of the managed refusal.** The refusal is scoped to managed launches, and `st2 eval` is not one
  (see *Limitations*). This tournament compares delegation *mechanisms*, not the policy that selects them.
- **Not a persona or model comparison.** Model, effort, permission posture, task bytes, graders, and fixture
  are matched; the delegation layer is the only manipulated variable.

## Arms

Four arms per task, because the naive three-arm shape (st2 vs Claude-native vs codex-native) confounds the
delegation mechanism with the model family. Each native arm therefore has a same-harness managed counterpart:

| arm | shape | delegation mechanism |
| --- | --- | --- |
| `claude-st2` | coordinator + delegate seats, all Claude | `st2 message send` to peer seats on the native bus |
| `claude-native` | one Claude seat | the harness's own `Agent` tool (`Explore`, `general-purpose`, …) |
| `codex-st2` | coordinator + delegate seats, all Codex | `st2 message send` to peer seats on the native bus |
| `codex-native` | one Codex seat | the harness's own `spawn_agent` / `followup_task` / `wait_agent` |

The comparison that answers the question is **within a harness family**: `claude-st2` vs `claude-native`, and
`codex-st2` vs `codex-native`. Cross-family rows are descriptive only.

## Tasks

Three tasks, all over the same frozen synthetic `noteflow` repository, each with a fan-out the task itself
declares. The task text is treatment-neutral: it names slices and deliverables, never a delegation mechanism.

1. **`delegation-sweep-*` — broad multi-file code search.** Which modules under `repo/src/` and
   `repo/scripts/` reach `legacyTitle()` at run time, through any chain of re-exports and wrappers? A plain
   text search answers it wrongly in **both** directions: it reports a pure re-export module, a comment, and a
   warning string, and it misses three modules that arrive through an alias or a wrapper. Fan-out 2.
2. **`delegation-review-*` — parallel independent review of a diff.** `review/proposed.patch` carries three
   real defects (shared-default mutation, an inverted `limit` guard, a boolean comparator) and two
   behaviour-preserving hunks that look suspicious. The suite is green with the patch applied, so the defects
   are invisible to the tests. Reporting a correct hunk is a false positive and fails. Fan-out 2.
3. **`delegation-implement-*` — a small, well-scoped implementation.** Collision-safe slugs in
   `repo/src/slug.js` plus a regression test that is genuinely RED against the pre-change implementation,
   suite green, nothing else touched. Fan-out 1: this task tests delegating implementation, not parallelism.

A fourth candidate — **research/synthesis** — is deliberately **deferred**, and this is a cost and oracle
decision, not a conventions one. The corpus already has an LLM-judge precedent (the `docs` cell's
`judge:cold-reader`, recorded in `evidence/harness-exclusions.tsv`), so a synthesis task is expressible. It is
excluded here because a synthesis endpoint needs a model judge whose discrimination has to be demonstrated
separately, and because the tournament is already a 36-run paid commitment. If it is added later it enters as
a fourth matched row of four cells, not as a variation of these three.

## Matched conditions

Within one task, all four arms share **identical bytes** for: `task.md`, `judges/grade.sh`,
`judges/observe.sh`, `judges/repo.sha256`, `fixture/repo/**`, `fixture/findings/CONTRACT.md`, the reviewed
patch, the held-out `mutations/**`, the `max-timeout` (`900s`), and the kickoff target. Model and effort are
pinned corpus-wide (`claude-sonnet-5` at medium, `gpt-5.6-sol` at medium reasoning), and every seat uses the
same bypassing permission posture and the same event-first launch prompt for its harness.

The **treatment** is exactly two things: which seats exist, and the coordinator persona that says who the
delegates are. The coordinator persona is byte-identical across tasks within an arm, and the st2 delegate
persona is byte-identical everywhere.

Two authoring decisions follow from what a folder eval actually provides, and both are checked:

- **The managed coordinator names its delegates (`dg.w1`, `dg.w2`); it does not discover them.** A compact
  folder eval builds its team in process, so a hermetic catalog holds no Agent Spec declarations on disk and
  roster discovery there answers with the *fixture's own files* — `st2 agents --catalog <catalog> --json`
  returns `[{"identity":"repo.package",…}]`, the product `package.json`, and no seat. Every cell therefore uses
  one uniform team prefix so the single shared coordinator persona can address peers by identity, and
  `bin/check-delegation-parity.sh` fails if a declared delegate identity is missing from that persona.
- **The deliverable contract admits the native delegation log.** `findings/CONTRACT.md` is arm-neutral and
  identical across arms, so it must not tell a native coordinator that a file its own persona requires — and
  that its delegation judge gates on — is unread. The gate asserts the contract names `delegation-log.md`.

Because the outcome oracle is one shared script, it cannot favour an arm. `grade.sh` receives the arm name
**only** for the delegation-evidence judge; every outcome, slice, suite, regression, and isolation mode is
arm-blind. Deliverables land in a shared `findings/` directory with a `delegate:` attribution line, so a bus
delegation and a native fan-out are read identically.

`bin/check-delegation-parity.sh` proves all of the above, plus the tasks' premises (the baseline suite is
green; the reviewed patch applies and stays green; the held-out pre-change implementation is the shipped one),
without starting a model.

## Metrics per run

| metric | how it is obtained | status |
| --- | --- | --- |
| outcome | the cell's gating judge vector and `VERDICT` from `st2 eval` (task-specific mechanical assertions, never a rubric) | primary |
| task latency | the interval between the kickoff receipt in the coordinator's mailbox and the coordinator's confirmation in the requester's mailbox, derived from bus message filenames by `judges/observe.sh` | secondary |
| round-trips | bus message count and seat count for st2 arms; recorded delegate count for native arms, from `findings/delegation-log.md` | descriptive |
| tokens / cost | not produced by `st2 eval` — the runner captures no usage at all. Recorded by the operator into `evidence/run-history.tsv` exactly as existing rows are, from the harness's own usage output for that run | descriptive |

**Runner wall-clock is not the timing metric.** A compact single-seat eval never signals completion to the
runner, so every native cell consumes its whole `max-timeout` regardless of when the work finished. Bus
latency is the only arm-comparable timing signal, which is why it is measured from mailbox timestamps
instead. Round-trip counts are measured on **different substrates per arm** (durable bus files versus a
self-attested log) and are therefore descriptive, never a pass criterion.

Because `st2 eval` discards judge stdout and keeps no metric fields, the non-gating `observations` **signal**
judge appends one row per run to the ignored working-tree sink `.eval-runs/observations/<cell>.tsv`.

## Replication: n = 3

**Intended n is 3 runs per cell**, i.e. 12 cells × 3 = **36 paid runs**. Three is the smallest n at which a
single flake cannot decide a task: with n = 1, one lost DING or one unlucky sampling inverts a task's
direction, and with n = 2 a 1–1 split is uninterpretable. Three keeps the verdict rule ("strictly fewer PASS
runs in at least 2 of 3 tasks") from resting on single observations while staying inside one overnight budget.
It is still a small sample and the reporting rule below stays descriptive.

`st2 eval` has no repeat facility and `bin/overnight.sh --run` rejects a duplicated `--cell`, so replication is
**operator-driven**: three separate passes over the 12 cells, alternating arm order between passes, each run
recorded as its own `evidence/run-history.tsv` row.

Suggested execution, staged so the cheap failure modes surface first:

- **Stage A (12 runs, no verdict).** One run per cell. Purpose: confirm every arm boots, that both native
  harnesses actually fan out, and that the graders behave on real output. Any oracle defect found here is
  fixed and Stage A is redone; Stage A results are design evidence, not verdict evidence.
- **Stage B (24 runs).** Two further passes over all 12 cells. The verdict is computed over Stages A+B only if
  Stage A required no grader change.

## Rerun policy

A run is an **infrastructure flake** and is rerun rather than scored when, and only when, one of these is
visible in the durable log before any product work started: a declared seat failed the boot gate; a harness
authentication or quota error; a hard usage/rate-limit stop; the watchdog fired with an empty `findings/`
directory; or the observation row shows no kickoff receipt. Anything else — including a timeout with work in
progress, a wrong answer, a false positive, a lane violation, and a coordinator that did the work itself — is
a **scored FAIL**. Preregistering this is what keeps "flake" from becoming an unfalsifiable escape hatch.

## Pass criterion and what would falsify it

Let `PASS(task, arm)` be the number of PASS verdicts out of n = 3.

**"st2-managed delegation is not dramatically worse" is falsified for a harness family if either holds:**

1. **Outcome.** In at least **2 of the 3 tasks**, the managed arm has **strictly fewer** PASS runs than its
   same-harness native arm.
2. **Latency.** In at least **2 of the 3 tasks**, the managed arm's **median bus latency** is more than
   **2×** its same-harness native arm's median bus latency, while outcomes are tied.

Anything else — including the managed arm losing one task, or being uniformly somewhat slower — is reported as
**not falsified**, with the numbers shown. A managed arm that *wins* is reported as such and claims nothing
causal. The factor-of-two latency bar is deliberately coarse: managed delegation pays real bus hops that a
single-seat native fan-out does not, and that structural cost is expected, not a defect.

The result is reported per family as a judge vector plus the observation rows, with exact commits and
receipts. Six runs per task per family is a descriptive replication, not an identified effect.

## Limitations

1. **The native arms run unmanaged, and cannot do otherwise.** `st2 eval` launches `exec claude` / `exec
   codex` directly, so `AGENT_LAUNCH_HOSTED` is unset and the fleet's native-spawn refusal never fires. That
   is what makes the native arms runnable at all — and it means this tournament compares managed delegation
   against **unmanaged** native delegation. "Claude-native inside a managed session" is impossible by
   construction, so nothing here tests the refusal itself.
2. **Native fan-out is self-attested.** For an st2 arm, delegation is a durable bus fact. For a native arm the
   only positive evidence is the coordinator's own `findings/delegation-log.md` plus per-delegate attributed
   deliverables. The one mechanical guarantee is negative and is enforced: a native cell declares exactly one
   bus seat, and its delegation judge fails if a second bus mailbox ever appears, so a native arm cannot
   quietly delegate over the bus.
3. **Seat counts differ by construction.** A managed arm is 2–3 seats and a native arm is 1. Cost bands and
   token totals are therefore not comparable across arms, and per-arm cost is reported for budgeting only.
4. **No git in the fixture.** Grading is on the worktree plus a frozen hash manifest and a mutation replay.
   Commit-authorship isolation, which `ghost-bug` uses, cannot discriminate arms here: a native sub-agent
   commits under the same identity as its parent.
5. **Ambient harness configuration is not fully controlled.** Personas, loaders, and hooks are baked into the
   fixture per the corpus harness contract, but a seat still boots against the host's ambient harness config.
   For codex this matters concretely: the shipped build carries a `<multi_agent_mode>` developer instruction
   that suppresses proactive sub-agent use "unless the user or applicable AGENTS.md/skill instructions
   explicitly ask", which is why the `codex-native` persona asks explicitly.
6. **Both native spawn surfaces were verified present, not exercised.** `codex debug prompt-input` on
   `codex-cli 0.146.0` shows the collaboration tools (`spawn_agent`, `followup_task`, `wait_agent`,
   `send_message`, `interrupt_agent`, `list_agents`) in the model-visible prompt, and `multi_agent` /
   `multi_agent_v2` are stable-on. Claude Code exposes its `Agent` tool by default and the canonical corpus
   `.claude/settings.local.json` restricts no tools. Neither has been observed fanning out inside a cell yet;
   that is Stage A's job.
7. **n = 3 with binary judges is coarse.** A task where every arm passes three times is uninformative about
   quality differences; the design accepts that, because the question is regression detection, not ranking.

## Cost and schedule shape

| arm | seats | cost band | per run |
| --- | --- | --- | --- |
| `st2-*` sweep / review | 3 | high | ≤ 900 s |
| `st2-*` implement | 2 | medium | ≤ 900 s |
| `native-*` (all tasks) | 1 | low | always ≈ 900 s (a single-seat compact eval never signals completion) |

One pass over the 12 cells is 4 high, 2 medium, and 6 low cells; three passes is 36 runs. Every cell is
selected explicitly — no run in this tournament may start from an inferred authorization.
