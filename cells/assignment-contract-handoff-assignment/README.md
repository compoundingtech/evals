# assignment-contract-handoff-assignment

Assignment handoff control for the resource-binding tournament. Both workers retain the same tagged,
URI-identified context resources. Exactly one worker has an active Assignment selecting the stable `work`
resource at a time.

The requester sends a task-free kickoff to an eval-only deterministic controller. The controller wakes the
supervisor and worker A. A resolves the work URI and commits the first incomplete phase. The controller then
publishes two atomic Agent Spec revisions:

1. change A from active to idle, leaving both Assignments idle; and
2. change B from idle to active with the exact same Assignment ID.

The controller records both revisions before waking A and B. A must observe that it no longer has work and
remain idle. B resolves the same work URI plus the worklog and repository resources, completes the next
incomplete phase, and reaches a pre-commit checkpoint. The controller's explicit `st2 pty restart -y arh.b`
must succeed, and it withholds the checkpoint release until st2 exposes a replacement PTY with distinct PID,
creation time, and derived session-instance identity. B must then finish from the dirty worktree under the
same durable contract. Eval-wide supervision stays disabled so the deterministic controller cannot restart.

All judges are model-free and held out. They verify transition exclusivity, stable URI identity, resolver
authorization through active Assignment `uses`, commit authorship and order, no post-revocation A commits,
restart continuity, bus ordering, the final behavior, tests, and a clean repository. The supervisor reports
read-only verification to the
controller; only the controller can close the requester after independently checking that evidence. This
prevents an early worker or supervisor report from ending the eval.

A restarted PTY may currently lose `ST_AGENT`; this eval records that as a st2 restart-context limitation and
does not add an identity workaround beyond st2's existing explicit PTY identity.

This control asks whether an Assignment wrapper improves a revoke-before-grant handoff over moving a direct
resource named `work`.
