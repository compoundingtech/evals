# assignment-contract-cold-assignment

Cold-start Assignment control for the resource-binding tournament. It preserves the
`license-mit-codex` supervisor/worker topology and mechanical result, but removes
all task facts from the kickoff. The supervisor must orient from the experimental
Agent Spec and resolve its declared resources.

This treatment contains the same direct tagged resources as its matched siblings,
plus exactly one minimal active Assignment. The Assignment has the work Resource
URI as its stable ID and only groups the `intent`, `source`, `worklog`, and
`delivery` bindings through `uses`.

The control asks whether the wrapper improves cold discovery over a direct resource named `work`. The Agent
Spec is a fixture document because folder evals do not currently parse experimental `resource` or `assignment`
nodes. The cell therefore measures agent orientation and execution, not native st2 reconciliation.

Free checks:

```sh
bash ./judges/contract.sh
bash ./judges/outcome.sh
bash ./judges/coordination.sh
bash ./judges/self-test.sh
```

Paid E2E (not part of free validation):

```sh
st2 eval ./cells/assignment-contract-cold-assignment/ --keep
```
