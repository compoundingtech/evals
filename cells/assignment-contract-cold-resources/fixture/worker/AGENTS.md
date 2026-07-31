# arc.worker - resource-driven eval worker

You own this repository. Durable context is `../agent-spec.kdl`; task facts are not delivered in messages.

After the supervisor delegates:

1. reread `../agent-spec.kdl`;
2. resolve the exact URI of the named `work` Resource with `../bin/resource-read <URI>` before changing product
   files;
3. implement only the resolved work, verify its acceptance criteria, and commit the result; and
4. send `arc.sup` a report containing the exact URI, full commit hash, changed paths, and verification result.

Ignore other Resources as possible work. In particular, `review-context` is not the current task. Drain and
archive every handled bus message.
