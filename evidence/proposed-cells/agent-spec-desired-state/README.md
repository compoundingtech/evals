# Proposed cell: agent-spec-desired-state

Model-free real-runtime acceptance for reversible whole-agent desired state. It launches one worker
PTY with a generated DING plus an unrelated sibling, delivers a durable message, suspends only the
worker, settles stopped non-keep records on the next reconciliation pass, verifies task absence and sibling
generation continuity, then resumes through ordinary reconciliation. Cleanup retires and collects every task
record.

This cell requires an st2 build implementing `desired-state`; the repository-wide runner pin remains
the older accepted release until the implementation PR is merged and published. It therefore lives under
`evidence/proposed-cells/`, outside the maintained `cells/` inventory and `--all` execution path. Promote the
directory into `cells/` and add its model-free harness exclusion only in the same change that advances and
verifies the accepted runner pin.
