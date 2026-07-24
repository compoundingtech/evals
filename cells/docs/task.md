---
subject: "document the checkout library so a new dev can use it cold"
priority: high
---
We're about to hand the `checkout` library (the repo your writer `doc.writer` owns) to a new developer
who will use it **with only its docs — they won't read the source**. Right now the README is a stub.

Please get it documented properly. Delegate to `doc.writer` (they own the repo) and have them:
1. **Read the whole library + its tests** to understand how it actually behaves.
2. Write **`README.md`** (and `docs/` if useful) so a newcomer with ONLY the docs can use `checkout`
   correctly — including the **non-obvious things they can't guess**: unit conventions, whether the API
   mutates or returns new values, any required call order, and the exact shapes returned.
3. Include at least one **runnable, correct worked example** end to end.
4. Keep it a DOCS change: **don't change the library's behavior** (`src/` stays as-is), tests stay green.
5. Commit, and report what was documented + the gotchas surfaced.

Verify read-only when they report — could a new dev use it correctly from the docs alone? — then reply
to me with the summary and your verification, only once it's done and verified. Stay in lanes:
`doc.writer` touches only its own repo; coordinate by message.
