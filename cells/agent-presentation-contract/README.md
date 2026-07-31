# agent-presentation-contract

Model-free acceptance coverage for stable Agent Spec identity and mutable
presentation metadata across the native st2 and PTY boundary.

Two live agents deliberately share one display name. Stable IDs remain the
only st2 routing, authorization, task, and lifecycle keys, while PTY human
lookup follows its exact-ID-first and fail-closed ambiguity contract. Changing
or clearing `name` and `description` updates the roster and managed
PTY metadata without changing the PTY ID, PID, creation timestamp, or process
generation. Repeating an unchanged reconciliation emits no metadata event.
Name and description accept at most 160 and 1,000 Unicode scalars respectively;
empty, untrimmed, multiline, and control text is refused.

Every managed PTY receives the same owned presentation schema, actor path,
and description tags. Only the primary agent PTY receives Agent Spec
`name` as its native display name; a secondary task keeps its task-specific
display behavior across presentation changes.

The same black-box fixture exercises source-preserving presentation authoring:
operator, self, and supervisor edits succeed; peer edits, Nix-owned sources,
and JSON/TOML declarations fail with classified receipts. Concurrent edits to
different presentation fields serialize through the catalog lock and preserve
both accepted values.

An explicit exact-ID primary-process kill is the lifecycle control: normal
reconciliation must create a new primary generation without disturbing its
secondary task or sibling agent. Explicit retirement remains the cleanup
boundary.
