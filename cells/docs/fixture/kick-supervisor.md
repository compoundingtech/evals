<!--
HERMETIC KICK for the Docs ("Explain it") eval. The ONLY input. Seeded by spin.sh into doc-sup's coord
inbox with a boot-time ms filename so the boot ritual ACTS on it. `from:` is the synthetic requester
(eval-runner) so the loop is observable + reproducible. spin.sh strips this HTML header.
-->
---
from: eval-runner
subject: "document the checkout library so a new dev can use it cold"
priority: high
---
We're about to hand the `checkout` library (the repo your writer `doc-writer` owns) to a new developer
who will use it **with only its docs — they won't read the source**. Right now the README is a stub.

Please get it documented properly. Delegate to `doc-writer` (they own the repo) and have them:
1. **Read the whole library + its tests** to understand how it actually behaves.
2. Write **`README.md`** (and `docs/` if useful) so a newcomer with ONLY the docs can use `checkout`
   correctly — including the **non-obvious things they can't guess**: unit conventions, whether the API
   mutates or returns new values, any required call order, and the exact shapes returned.
3. Include at least one **runnable, correct worked example** end to end.
4. Keep it a DOCS change: **don't change the library's behavior** (`src/` stays as-is), tests stay green.
5. Commit, and report what was documented + the gotchas surfaced.

Verify read-only when they report — could a new dev use it correctly from the docs alone? — then reply
to me (`eval-runner`) with the summary and your verification. Stay in lanes: `doc-writer` touches only
its own repo; coordinate by message.
