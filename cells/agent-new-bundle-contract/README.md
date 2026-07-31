# agent-new-bundle-contract

This model-free cell freezes the deterministic half of the `axe agent new`
interview handoff. A small semantic `axe.agent-creation-intent.v1` record is
the only interviewer output. The renderer owns canonical Agent Spec KDL and
the initial inbox Resource.

Two valid one-session intents exercise the same lowering path, including an
empty-reference root session and a supervised session. Workspace is supplied by
the creation transaction, never by model output. Invalid inputs prove the
closed boundary rejects account pins, model-owned workspace, malformed
supervisors, unsupported trajectory values, and any attempt to override an
explicit human trajectory constraint.

Held-out mutation checks copy valid output and independently prove that the
bundle grader rejects:

- a bare provider argv in place of `axe agent launch`;
- drift between typed intent and the KDL trajectory; and
- a missing initial inbox Resource.

Run it with:

```sh
st2 eval ./cells/agent-new-bundle-contract/
```
