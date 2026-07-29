# agent-spec-lifecycle-catalog-root-atomicity

Product-conformance cell for catalog-root transactions.

Two seats are staged without changing visibility. Root CAS rejects a stale
writer, and graph validation rejects a cross-seat ref/binding join without
moving the root. A valid two-seat Nix admission then commits both changes under
one root identity; concurrent readers see only complete old/new roots. Finally,
a dynamic manager admits a distinct seat without changing either Nix admission,
while both managers remain fenced from the other's refs. Corrupting an admitted
immutable object then makes resolution fail closed.
