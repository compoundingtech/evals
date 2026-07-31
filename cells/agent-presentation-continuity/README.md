# agent-presentation-continuity

Model-free acceptance coverage for adding, changing, and clearing Agent Spec
presentation metadata without changing stable identity or the live process
generation.

The cell begins with the existing positional stable ID and a conflicting
legacy sibling `name` file. It proves that Agent Spec is authoritative: absent
presentation does not fall back to the sibling file, and declared `name` and
`description` appear in the roster after an in-place catalog
edit. Across add, repeat, change, and clear reconciliations it requires the
same PTY ID, PID, creation timestamp, and single `session_start` event.

The same transitions must preserve unread and archived messages, context,
decisions, resources, presence, and terminal transcript. Cleanup uses the
existing explicit retirement lifecycle and leaves no PTY state.

This cell does not retire the existing `identity` grammar. Schema versioning
and breaking grammar changes belong to compoundingtech/st2#127; this cell is
the additive evidence for compoundingtech/st2#128.
