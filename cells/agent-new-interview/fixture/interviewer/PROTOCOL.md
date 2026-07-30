# Eval transaction protocol

This fixture supplies the deterministic submission seam of the enclosing
creation transaction. Read `hard-constraints.json`; every present value is a
human constraint and must be preserved exactly. The transaction already owns
the current workspace, so workspace is not model output.

Submit exactly one closed payload with `./submit-intent` on stdin:

```json
{
  "schema": "axe.agent-creation-intent.v1",
  "decision": "commit",
  "identity": "<four-segment-purpose-identity>",
  "goal": "<non-empty-goal>",
  "references": [],
  "trajectory": {
    "harness": "claude|codex",
    "model": "<profile model>",
    "effort": "medium|high",
    "persona": "<profile persona>",
    "mode": "managed-unattended",
    "boot": "managed-v1"
  },
  "supervisor": "<optional policy-valid identity>"
}
```

`supervisor` is optional. Unknown fields, account pins, provider argv, KDL,
catalog paths, and lifecycle fields are forbidden. Do not wait for a second
request when the one-sentence input and references already determine a useful
intent.
