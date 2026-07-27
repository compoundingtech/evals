# evals requirements

## Context

The corpus produces and validates the root
[`AGENT-SPEC.md`](../../AGENT-SPEC.md). The vision is defined in
[vision.md](./vision.md).

## Assumptions

- **A01 Real harnesses:** Claude and Codex may require different overlays and
  hooks while implementing the same agent contract.
- **A02 Mixed judges:** Deterministic, cross-model, and LLM judges are all
  valid when their grading behavior is explicit and tested.

## Acceptable Tradeoffs

- **T01 Bounded coverage:** Sequential, cost-bounded evidence is preferable to
  an unbounded all-provider run.
- **T02 Evidence before prose:** `AGENT-SPEC.md` may lag a proposed idea until
  executable evidence is accepted.

## Requirements

### Must make every cell reproducible

- **R01 Tracked cells:** Every maintained eval is an executable, inventoried
  cell with its declaration, fixture, task, judges, and cleanup behavior in
  version control.
- **R02 Explicit models:** Every provider launch declares its model and effort;
  no eval inherits an expensive personal default.
- **R03 Real hooks:** Harnessed cells use the actual Claude or Codex hook
  behavior they claim to evaluate. Agent hooks and personas are baked into the
  fixture rather than resolved from mutable external defaults.
- **R04 Valid judges:** Judges discriminate the intended outcome and have
  mutation evidence showing that relevant bad outcomes fail.
- **R05 Hermetic fixtures:** Fixtures contain every hook and persona used by
  their launched agents and declare every other dependency that affects the
  result.

### Must bound execution

- **R06 Bounded provider use:** Agent count, timeouts, concurrency, stop
  conditions, and provider usage are explicit before a paid run.
- **R07 Cleanup:** Every run terminates its launched agents and detects
  leftover processes.
- **R08 Durable receipts:** Runs record enough state to audit, resume, and skip
  completed work safely.
- **R09 Visible cost:** Model, effort, usage, and observed cost are visible per
  eval and, when runs are batched, per batch.

### Must derive the spec from evidence

- **R10 Executable specification:** `AGENT-SPEC.md` is extracted from accepted
  executable scenarios; the corpus proves ideas before the prose declares them
  supported.
- **R11 Fast authoring:** A new agent idea can become a validated, runnable eval
  by adding declarative scenario content rather than changing the runner or
  building one-off infrastructure.
- **R12 Universal run model:** Every agent and ordinary agent run can be
  represented as an eval with explicit inputs, hooks, model, lifecycle,
  evidence, cleanup, and receipts, and executed by the current runtime.
