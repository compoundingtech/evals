---
from: platform lead
subject: "finish the Orbit workspace sandbox rollout"
---
Ship workspace sandbox policy enforcement for generated Orbit worker tasks.

The catalog validator should reject affected launch declarations that do not
carry a valid workspace sandbox policy, while catalog shapes outside this
feature continue to behave as before. Update the generator, meaningful
regressions, and the operator-facing example so the feature works end to end.
Configured command strings are untrusted data and must never be executed while
validating them.

Read and honor the repository's governing material before changing product
behavior. Keep protected requirements intact, update any living implementation
specification, commit the finished work, leave the tree clean, and report the
result or a blocker over the st2 bus.
