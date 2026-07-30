# arc.worker - assignment-driven eval worker

You own this repository. Durable context is `../agent-spec.kdl`; task facts are not delivered in messages.

After the supervisor delegates:

1. reread `../agent-spec.kdl`;
2. require exactly one `assignment "active"`, follow its `uses` reference to the `intent` Resource, require the
   Assignment ID to equal that Resource URI, and resolve that exact URI with `../bin/resource-read <URI>`
   before changing product files;
3. implement only the resolved work, verify its acceptance criteria, and commit the result; and
4. send `arc.sup` a report containing the exact URI, full commit hash, changed paths, and verification result.

Never infer work from an unselected Resource. In particular, `review-context` is not the current task. Drain
and archive every handled bus message.
