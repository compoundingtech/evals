# agent-spec-lifecycle-catalog-prepare

Product-conformance cell for the first content-addressed catalog boundary. It
invokes `st2 catalog prepare` directly and proves that prepare imports the exact
Agent Spec bytes idempotently without creating a catalog root or making the
seat visible.
