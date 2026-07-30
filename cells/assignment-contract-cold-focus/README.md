# assignment-contract-cold-focus

Cold-start Focus control for the resource-binding tournament. The synthetic license task is expressed as direct
tagged resource bindings plus one `focus` selector. There is no Assignment entity, holder, or lifecycle state.

The generic kickoff carries no task facts. The supervisor reads the experimental `agent-spec.kdl`,
follows `focus "intent"`, and resolves URIs through `bin/resource-read`. The resolver logs exact reads
to `.oracle/resource-reads.jsonl`; held-out mechanical judges grade orientation, output, isolation,
commit hygiene, and bus coordination. The GitHub PR is an unrelated distractor.

This control asks whether a selector improves cold discovery over a direct resource named `work`. The generic
task and product oracle match the direct-resource and Assignment siblings.

Free oracle regression:

```sh
bash ./cells/assignment-contract-cold-focus/judges/self-test.sh
```

Paid E2E: `st2 eval ./cells/assignment-contract-cold-focus/`.
