# assignment-contract-cold-resources

Cold-start E2E candidate for a resource-only Agent Spec contract. The requester gives the supervisor no task
facts. The worker must discover durable intent from one named `work` resource, resolve its URI through the
fixture resolver, and distinguish it from a tempting but non-work pull request resource.

The candidate intentionally has no focus, assignment, holder, or lifecycle-state wrapper. Its other resource
bindings are ordinary tagged resources: source worktree, Axe worklog, DING delivery endpoint, and review
context.

All judges are mechanical. They require:

- the issue URI to be resolved first, while the product files still match their frozen baseline;
- every resolver read to use a declared URI;
- the MIT metadata and license to be committed without changing runtime code;
- a clean worktree; and
- the supervisor's post-verification completion to cite the exact work URI.

This is the selected treatment in the resource-binding tournament. Its Focus and Assignment siblings are
retained as matched controls. The experimental Agent Spec remains a fixture document because folder evals do
not yet project resource bindings into the runtime catalog.

Free oracle regression:

```sh
bash ./cells/assignment-contract-cold-resources/judges/self-test.sh
```
