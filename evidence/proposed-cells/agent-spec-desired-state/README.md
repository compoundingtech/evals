# Proposed cell: agent-spec-desired-state

Model-free real-runtime acceptance for reversible whole-agent desired state. It launches one worker
PTY with a generated DING plus an unrelated sibling, delivers a durable message, suspends only the
worker, settles stopped non-keep records on the next reconciliation pass, verifies both task absence and
exact worker/DING process death while preserving sibling generation continuity, then resumes through ordinary
reconciliation. It also requires Doctor to accept the converged suspended declaration and checks declaration
intent on both the worker and generated DING task. Cleanup retires and collects every task record and independently
proves every resumed process identity has ended. Additional controls prove live keep-pinned work is stopped while
its dead evidence remains, pre-existing presence remains independently observable, context and linked resources survive, and unrelated
declaration bytes round-trip exactly across suspend and resume. Doctor must reject the intermediate dead non-keep
state before accepting settled absence, and suspended reconciliation must not recreate removed rendered output.

This cell requires an st2 build implementing `desired-state`; the repository-wide runner pin remains
the older accepted release until the implementation PR is merged and published. It therefore lives under
`evidence/proposed-cells/`, outside the maintained `cells/` inventory and `--all` execution path. Promote the
directory into `cells/` and add its model-free harness exclusion only in the same change that advances and
verifies the accepted runner pin.
