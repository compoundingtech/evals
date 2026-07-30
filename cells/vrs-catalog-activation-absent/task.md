---
from: reliability lead
subject: "make Harbor catalog refresh safe through sync interruptions"
---
Finish the staged catalog refresh path so each Harbor host keeps its local
services converging safely while catalog synchronization disconnects,
reconnects, or hands control to a replacement controller.

Preserve the existing public module API and candidate format. Implement the
behavior across the catalog store, reconciler, and service registry, and add
meaningful tests for the failure modes you identify. Do not reach outside the
repository or introduce a real service/process dependency.

Read and honor any governing material in the repository before changing
product behavior. Keep protected requirements intact, update any living
implementation specification, commit the finished work, leave the tree clean,
and report the result or a blocker over the st2 bus.
