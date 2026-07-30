# agent-new-interview

This is the paid judgment half of the B2 `axe agent new` proposal. A
short-lived Claude Sonnet interviewer receives exactly one sentence from the
human. It is launched through the typed `axe agent launch` boundary with no
durable account pin, so Axe selects from the configured account pool for that
run. It may inspect the frozen local snapshot of the referenced issue, then
submits one typed semantic intent record.

The interviewer cannot write the final Agent Spec. `submit-intent` validates a
closed input schema and deterministically renders:

```text
semantic intent
  |
  +-- agents/evalhost/<identity>/agent.kdl
  `-- agents/evalhost/<identity>/resources/inbox/0001-session-goal.md
```

The scenario is intentionally answerable without a clarification round. It
tests whether the interviewer derives a useful hierarchical identity, the
implementation trajectory, an externalized goal, and the reference from a
normal terse request.

Run it only with explicit paid-run authorization:

```sh
st2 eval ./cells/agent-new-interview/
```

## Canonical eval seam

The cell copies its fixture, deterministically publishes one canonical
`agents/evalhost/interviewer/agent.kdl` from the active runtime profile, and
then opts into st2's `canonical-agents` admission. The profile supplies the
exact immutable Axe adapter, absolute runtime-profile path, and canonical
generalist prompt. The declaration itself owns the typed launch trajectory and
contains no account pin.

This makes the paid cell environment-bound by design: the selected runtime
profile is an explicit test prerequisite and part of the run evidence. The
cell is not hermetic across different profile artifacts.

st2 validates and materializes that declaration before launch, routes the
kickoff through its canonical inbox, and requires a fresh interviewer reply
before the singleton eval can complete. The paid judgment run remains held
until the host's Claude workspace-trust projection has independent evidence;
the model-free bundle cell does not prove provider readiness.
