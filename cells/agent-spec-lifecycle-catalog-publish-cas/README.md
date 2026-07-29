# agent-spec-lifecycle-catalog-publish-cas

Product-conformance cell for explicit immutable staging. Ref CAS expects a
parent commit identity, not only an object identity, so A-B-A cannot revive a
stale writer. Operation replay is idempotent, manager ownership is fenced, and
none of the staging operations changes the selected catalog root.
