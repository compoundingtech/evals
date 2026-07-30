# agent-new-interview

This is the paid judgment half of the B2 `axe agent new` proposal. A
short-lived Claude Sonnet interviewer receives exactly one sentence from the
human. It may inspect the frozen local snapshot of the referenced issue, then
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
