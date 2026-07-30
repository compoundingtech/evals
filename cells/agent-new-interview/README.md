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

## Current composition gate

This proposed cell intentionally uses the production typed launch boundary.
The current `st2 eval` team loader still boots `team { agent { command ... } }`
seats as transient commands; it does not materialize those seats as canonical
Agent Specs in the temporary catalog.

Current Axe admission requires:

1. `CATALOG`, `ST_ROOT`, and `PTY_ROOT` to agree on the st2 eval catalog; and
2. `ST_AGENT` to resolve to exactly one canonical Agent Spec.

With the eval roots supplied, admission reaches the second check and rejects
`new.interviewer` because the temporary catalog contains zero canonical Agent
Specs for that identity. Therefore this paid cell currently fails at boot
before account selection or provider launch. Tokenlens can independently
return an eligible Claude account, so lack of pool quota is not the blocker.

The principled fix belongs at the st2 eval/Axe composition seam: eval team
seats should be represented by canonical Agent Specs (or eval should directly
execute a canonical fleet declaration) and export the catalog-derived roots.
This cell must not work around the gap by fabricating an Agent Spec from inside
the seat, pinning an account in KDL, or launching bare Claude with ambient
credentials.
