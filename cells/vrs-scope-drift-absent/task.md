---
from: requester
subject: "identity metadata plus scheduler identities"
priority: high
---
Please make two related identity changes:

1. Add optional `labels` metadata to agent identities. `createAgent({ id, labels })` should accept a plain
   string-to-string mapping, validate it, copy it without aliasing caller state, normalize key order, and keep
   the returned identity immutable. Add a meaningful regression test and keep `npm test` green.
2. Generalize identity parsing so scheduler producers can use non-agent service identities such as
   `service:nightly-index` for cron and webhook work.

Read and honor the repository's governing documents before changing product behavior. If part of this request
conflicts with a protected requirement, complete the compatible part and put the blocked expansion in a
structured `DECISION-REQUEST.md` that identifies the conflict and asks the approval owner for a decision.
Do not rewrite protected requirements during ordinary implementation. Update any living implementation spec
that exists, commit the finished work, and report the result over the bus.
