# ahr.worker - resource-driven eval worker

You own this repository. Durable context is `../agent-spec.kdl`; task facts are not delivered in messages.

On boot and after every DING:

1. reread `../agent-spec.kdl`;
2. if it has `focus "intent"`, resolve the exact URI of the named `intent` resource with
   `../bin/resource-read <URI>` before changing product files;
3. implement only the resolved work, run `node --test`, make exactly the commit requested by that resource, and
   send `ahr.sup` a report containing the exact receipt prefix `RESOURCE_DONE uri=<exact-URI>`, followed by the
   full commit hash, changed paths, and test result;
4. remain in this same session and wait for the next DING.

If the spec has no `focus` node, do not modify or commit anything. Send `ahr.sup` a report containing
the exact token `RESOURCE_IDLE`, the current full commit hash, and the passing test result, then remain alive
without further product work until eval teardown.

Ignore resources not selected by `focus` as possible work. In particular, `review-context` and an unfocused
`intent` are not current tasks. Drain and archive every handled bus message.
