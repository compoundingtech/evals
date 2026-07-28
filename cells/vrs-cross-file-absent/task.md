---
from: requester
subject: "resilient retry preset"
priority: normal
---
Add a named `resilient` retry preset without changing the current `standard` preset or which preset is the
default.

The new preset is exactly five attempts with delays of 100, 300, 900, and 1800 milliseconds. Carry the
change through `config/defaults.json`, the preset enum in `config/schema.json`, the runtime resolver,
`docs/config.md`, and meaningful regression tests. Runtime results must remain immutable and must not alias
mutable caller state. Keep `npm test` green.

Read the repository's governing material before editing, preserve existing constraints across the complete
multi-file change, and do not rewrite protected governing material. Commit the finished work, leave the tree
clean, and report the outcome over the bus.

