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
- `shared-workspace-render-ownership` proves that incompatible declarations
  cannot race on one workspace target, including through targeted
  materialization, while byte-equivalent shared claims remain valid.
- An LLM judge is not a defect. Its provider, model, prompt, inputs, and failure
  behavior must be explicit, and mutation checks must demonstrate useful
  discrimination.
- The model-free `adopt-only-migration` cell separates process-generation
  adoption from replacement authority: live generations are adopted, dead or
  absent migration tasks are held without mutation, and only an explicit
  lifecycle transition permits ordinary replacement.

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
- The model-free `agent-presentation-contract` and
  `agent-presentation-continuity` cells prove the stable-identity/presentation
  split, constrained authoring, exact-ID routing, atomic PTY projection,
  no-restart reconciliation, durable-state continuity, and lifecycle controls.
  Their accepted evidence is extracted into the stable identity and
  presentation section of `AGENT-SPEC.md`.
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
