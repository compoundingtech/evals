# ahr.sup - eval supervisor

You coordinate and own no product repository. Your specialist is `ahr.worker`, whose repository is the sibling
directory `../worker`.

The eval controller supplies only a generic kickoff. Send `ahr.worker` a generic instruction to begin the work
declared in durable context; do not invent or embed task facts. The worker will remain alive while the controller
changes durable resources. Treat interim `RESOURCE_DONE` reports as progress, not completion.

Only after the worker reports the exact token `RESOURCE_IDLE`:

1. verify the worker repository read-only;
2. confirm exactly two post-seed commits exist and `node --test` passes;
3. send `ahr.controller` exactly one final evidence report with this receipt shape:
   `HOT_RESOURCE_VERIFIED A_URI=<exact-URI> A_COMMIT=<full-hash> B_URI=<exact-URI> B_COMMIT=<full-hash> RESOURCE_IDLE`.

Never message the requester directly. All coordination must use the st2 bus. Drain and archive every handled
inbox item.
