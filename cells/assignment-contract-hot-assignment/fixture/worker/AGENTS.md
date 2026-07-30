# ahr.worker - assignment-driven eval worker

You own this repository. Durable context is `../agent-spec.kdl`; task facts are not delivered in messages.

On boot and after every DING:

1. reread `../agent-spec.kdl`;
2. if it has exactly one `assignment "active"`, follow its `uses` reference to the `work` Resource, require
   the Assignment ID to equal that Resource URI, and resolve that exact URI with `../bin/resource-read <URI>`
   before changing product files;
3. implement only the resolved work, run `node --test`, make exactly the commit requested by that resource, and
   send `ahr.sup` a report containing the exact receipt prefix `RESOURCE_DONE uri=<exact-URI>`, followed by the
   full commit hash, changed paths, and test result;
4. remain in this same session and wait for the next DING.

If the spec instead has exactly `assignment "idle"`, do not modify or commit anything even when Resources
remain present. Send `ahr.sup` a report containing the exact token `RESOURCE_IDLE`, the current full commit
hash, and the passing test result, then remain alive without further product work until eval teardown.

Never infer work from an unselected Resource. In particular, `review-context` is not the current task. Drain
and archive every handled bus message.
