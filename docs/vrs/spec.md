# evals specification

This document specifies how the eval corpus realizes
[requirements.md](./requirements.md).

## Status

Active. The executable cells and their receipts are authoritative evidence;
this document maps their shared lifecycle.

## Scope

The repository owns the canonical Agent Spec contract and proof surface:
`AGENT-SPEC.md`, executable acceptance cells, harness overlays, grading,
cleanup, run receipts, and cost visibility. st2 is the current implementation,
not the contract owner. Evals defines and proves the executable run shape a
current or successor runtime consumes; the runtime's repository and product
name are not part of that stable contract.

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
- **R01, R04, R05, R07, R11:** The model-free
  `pty-attach-machine-stream` cell composes the installed PTY launcher, target
  daemon, remote route, forced transport replacement, and caller-owned framed
  descriptor. Its held-out judges require ordered `GEOMETRY`, `SCREEN`, live
  `DATA`, and terminal `EXIT` frames without stdout or stderr contamination,
  then require removal of every eval-owned process and PTY session. The fixture
  controls route selection and transport failure but does not import PTY source
  modules or bypass the packaged launcher.

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
  A speculative claim cannot become normative merely by editing the spec. A
  proposed behavior change updates both the canonical contract and its
  maintained proof cells before any implementation claims conformance.
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
- The model-free `agent-spec-resource-bindings` cell traces the portable
  Resource-envelope claims in `AGENT-SPEC.md` to native st2 parsing,
  machine-readable inspection, and reconciliation. It rejects malformed or
  policy-bearing bindings, preserves opaque tags and exact URI bytes in
  deterministic output, and proves that a Resource-only edit updates declared
  state without replacing a live task. Folder-eval Resource projection is not
  part of this acceptance boundary.
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
