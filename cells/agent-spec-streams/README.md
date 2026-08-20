# agent-spec-streams

Model-free E2E acceptance for the canonical Agent Spec stream contract introduced by
[`compoundingtech/st2#300`](https://github.com/compoundingtech/st2/pull/300).

The cell crosses the public parser, reconciliation, process, event-ingress, authoring, inbox, and task
inventory boundaries. Its negative controls prove the contract is fail-closed for invalid names, unsupported
intervals, ambiguous launch shapes, task collisions, undeclared streams, suspended recipients, and conflicting
event identity reuse. It also proves keyed-head to keyless supersession, strict discovery for ingress and
authoring, exact argv byte boundaries, and retained no-follow state/inbox/archive/temp-file capabilities that
prevent symlink redirection outside the agent directory. No model seat or paid provider is started.
