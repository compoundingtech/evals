# agent-new-interview

This is one of four paid, unrun judgment cases for `axe agent new`. A
short-lived Claude Sonnet session creator receives exactly one sentence from
the human. It uses the exact runtime-profile `session-creator` prompt and is
launched through typed `axe agent launch` with no durable account pin. It may
inspect a frozen local reference snapshot, then submits one typed semantic
intent record. Expected answers live only in held-out judges, never in the
model prompt.

The interviewer cannot write the final Agent Spec. `submit-intent` validates a
closed input schema and deterministically renders:

```text
semantic intent
  |
  +-- agents/evalhost/<identity>/agent.kdl
  `-- agents/evalhost/<identity>/resources/inbox/0001-session-goal.md
```

The four isolated cells cover a large implementation with a GitHub reference,
a small fix with empty references, a read-only investigation, and an explicit
human trajectory/supervisor constraint. They are intentionally answerable
without a clarification round. No paid result or autonomy acceptance is
claimed until all are run with durable receipts and DQ1 accepts a threshold.

Run it only with explicit paid-run authorization:

```sh
st2 eval ./cells/agent-new-interview/
```

## Canonical eval seam

The cell copies its fixture, deterministically publishes one canonical
`agents/evalhost/global.coding-agents.session-creation.interview-eval/agent.kdl`
from the active runtime profile, and
then opts into st2's `canonical-agents` admission. The profile supplies the
exact immutable Axe adapter, absolute runtime-profile path, and canonical
session-creator prompt. The declaration itself owns the typed launch trajectory and
contains no account pin.

This makes the paid cell environment-bound by design: the selected runtime
profile is an explicit test prerequisite and part of the run evidence. The
cell is not hermetic across different profile artifacts.

st2 validates and materializes that declaration before launch, routes the
kickoff through its canonical inbox, and requires a fresh interviewer reply
before the singleton eval can complete. The paid judgment run remains held
until the host's Claude workspace-trust projection has independent evidence;
the model-free bundle cell does not prove provider readiness.

The fixture setup creates the copied interviewer directory as a deterministic,
clean Git worktree before canonical admission. This is required because the
canonical overlay retains `git-exclude ".st2/"`, and materialization warnings
remain fatal.

The first authorized attempt is recorded in
[`evidence/agent-new-interview-attempts.tsv`](../../evidence/agent-new-interview-attempts.tsv).
It stopped at materialization before Axe, account selection, provider
readiness, or judges because the earlier fixture lacked that Git-worktree
setup. Cleanup removed the temporary catalog and process.
