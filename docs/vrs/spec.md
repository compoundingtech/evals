# evals specification

This document specifies how the eval corpus realizes
[requirements.md](./requirements.md).

## Status

Active. The executable cells and their receipts are authoritative evidence;
this document maps their shared lifecycle.

## Scope

The repository owns executable agent scenarios, harness overlays, grading,
cleanup, run receipts, cost visibility, and the evidence-derived
`AGENT-SPEC.md`. st2 is the current runtime. Evals defines and proves the
executable run shape a current or successor runtime consumes; the runtime's
repository and product name are not part of that stable contract.

## Cell contract

```text
tracked cell
  ├── KDL declaration with explicit model + effort
  ├── hermetic fixture with declared hooks/persona
  ├── task or scenario
  ├── judges + mutation checks
  └── cleanup and receipt policy
```

- **R01–R05:** The maintained inventory and model-free preflight reject missing
  declarations, inherited models, obsolete commands, undeclared harness
  behavior, invalid judges, and fixture escape.
- Hooks and personas must be baked into the fixture for every launched agent so
  the eval tests a controlled, reproducible real-work environment rather than
  mutable external defaults.
- An LLM judge is not a defect. Its provider, model, prompt, inputs, and failure
  behavior must be explicit, and mutation checks must demonstrate useful
  discrimination.

## Current execution

```text
preflight → explicit selection → launch → judge → cleanup → receipt
```

The current corpus runner requires an explicit subset or `--all`, launches
cells sequentially, judges them, cleans up, writes receipts, inspects usage,
and continues or stops.

- **R06–R09:** Runs have explicit budgets and stop conditions, clean up on
  completion or stop, leave durable receipts, and expose model, effort, usage,
  and cost. Resume validates the inputs and prior receipts.
- This current runner policy is not the permanent KDL execution model. Plans,
  steps, validation loops, schedules, external events, and long-running agents
  remain open for executable design rather than being constrained by this
  linear implementation.

## Spec extraction

- **R10:** A proposed capability begins as an executable scenario. Accepted
  evidence updates `AGENT-SPEC.md`; the prose links back to maintained cells.
  A speculative claim cannot become normative merely by editing the spec.
- Harness differences are recorded when the same contract needs different
  Claude and Codex mechanisms. They do not silently change the contract.
- **R11:** Adding a scenario does not require a custom runner path. Its
  declaration, fixture, task, judges, and lifecycle compose through the
  maintained cell contract and preflight.
- The matched `vrs-scope-drift-present` / `vrs-scope-drift-absent` experiment
  holds task, model, effort, code fixture, persona, timeout, and judges constant
  while varying only the synthetic identity requirements and living spec. Its
  model-free mutation gate proves that scope expansion, protected-requirement
  edits, missing spec upkeep, escalation-only output, and spec-only output fail
  the intended judges before either paid condition runs.
- **R12:** A normal agent run is the same declared execution unit as an eval
  run, even when its outcome is open-ended rather than a pass/fail grade. The
  current runtime—st2 today—executes that unit; evals supplies scenarios and
  evidence about whether the shape works.

## Human session-creation handoff

The `agent-new-interview` and `agent-new-bundle-contract` cells split the
human-facing creation workflow at one typed seam:

```text
one-sentence human request
  -> short-lived interviewer
  -> axe.agent-creation-intent.v1
  -> deterministic Agent Spec + initial inbox Resource
```

- **R01-R05:** The paid cell evaluates interviewer judgment from a frozen
  one-sentence request and local GitHub-reference snapshot. The model-free cell
  evaluates the renderer contract across multiple intents and closed-input
  failures. Held-out mutation controls reject raw provider argv, drift between
  intent and KDL, and missing initial context.
- **R06-R09:** The judgment cell uses one explicitly pinned Claude Sonnet agent
  at medium effort and a five-minute cell timeout. The deterministic cell has
  no model agent and a one-minute timeout. Normal st2 eval cleanup and receipt
  policy applies to both.
- The interviewer output is semantic intent, not KDL. Stable launch axes are
  explicit in that intent; the deterministic boundary owns canonical KDL,
  keeps account selection out of durable state, and places the goal and
  references in an initial inbox Resource.
- The renderer accepts workspace values only from a closed absolute-path
  alphabet and rejects invalid input before creating an Agent Spec. A
  model-free malicious-workspace control gates both renderers against KDL
  injection.
- The temporary interviewer itself launches through typed
  `axe agent launch` with explicit harness, model, effort, persona, mode, and
  boot axes. The cell does not pin `--account`: Axe selects an eligible
  account per run. Corpus inventory, model policy, lifecycle, and harness
  checks recognize this typed launch as a paid model agent and reject durable
  account pins.
- The paid cell uses st2's explicit `canonical-agents` seam. A deterministic
  pre-admission run first creates the copied interviewer workspace as a clean,
  deterministic Git worktree. A second run reads the active runtime profile
  and publishes one canonical interviewer declaration with its exact immutable
  Axe adapter, absolute profile path, and canonical persona source. st2 then
  carries that declaration unchanged through strict validation,
  warning-free materialization, launch, kickoff routing, singleton completion,
  and teardown. No compact eval agent, compatibility wrapper, account pin, or
  ambient provider launch participates.
- The paid cell is environment-bound to that explicit runtime-profile
  artifact; the artifact identity belongs in run evidence and results are not
  represented as hermetic across different profiles.
- One structured model-agent inventory is authoritative for both compact eval agents
  and canonical paid templates. Corpus cost classification, event-first
  policy, and harness-overlay checks consume its source-kind/path records;
  canonical template mutations prove required launch axes and overlays are
  non-vacuous.
- The canonical runtime seam removes the prior zero-Agent-Spec admission
  blocker. The paid judgment run remains held until the host's Claude
  workspace-trust projection is independently proven; model-free evidence
  does not establish provider readiness.
- The model-free `canonical-agent-runtime-smoke` cell independently proves the
  runtime seam with one deterministic shell Agent Spec: the same disposable
  Git-worktree shape, strict persona/bus overlay materialization with zero
  warnings, boot, canonical kickoff, fresh reply, and normal teardown, with no
  Axe, account, model, or provider harness.
- The first authorized paid attempt is evidence only for a pre-Axe fixture
  defect: required `git-exclude` materialization failed because the copied
  workspace was not a Git worktree. It reached no account selection, provider
  readiness, trust behavior, judge, or verdict and left no catalog or process
  residue. It cannot be represented as provider evidence.
- Passing model-free evidence proves the bundle boundary and its negative
  controls only. The autonomous-selection claim remains unaccepted until the
  paid judgment cell has a structured PASS receipt.
- **Future R04 lifecycle cell:** the eventual model-free recovery discriminator
  must operate on a real canonical temporary interviewer declaration and its
  durable transaction records. Its crash mutation removes only the temporary
  agent's main PTY generation. The DING sidecar may be live, stale, or already
  absent at that observation boundary, so its state is explicitly
  indeterminate and cannot be a gating proxy for interviewer liveness. The
  durable retired tombstone remains the authority that prevents resurrection;
  recovery must adopt or complete the exact transaction without a second final
  agent or inbox publication. This cell is deferred to a pinned st2 successor
  that exposes the required lifecycle boundary. A fake shell stand-in would
  not prove the contract and is not part of this PR.

The owner updates this spec with the corpus. Changing
[vision.md](./vision.md) or [requirements.md](./requirements.md) requires
Nathan's explicit approval.

## Open design questions

- **DQ1 Evidence threshold:** Define the exact passing evidence required before
  an executable scenario changes `AGENT-SPEC.md`. Resolve it with the first
  real spec-extraction change and preserve that behavior in a model-free gate.
- **DQ2 Universal run KDL:** Define how finite judged scenarios, long-running
  agents, plans, validation loops, scheduled runs, and externally triggered
  runs share one declaration, lifecycle, and receipt model without making
  evals a competing runtime. Prove the shape through executable scenarios
  before adding it to `AGENT-SPEC.md`, and keep successor runtimes possible.
