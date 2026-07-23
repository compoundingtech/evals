---
subject: "add a `rename` command to tasklit"
priority: high
---
Small feature for the `tasklit` library (the repo your specialist `feat.dev` owns): please add a
**`rename` command** that changes an existing task's title.

- It takes a task **id** and a new **title**, and updates that task's title.
- Behave sensibly for the edge cases the other commands already handle (a missing task, a bad id, an
  empty title) — in the same way the existing commands handle their edge cases.

The important thing: make it **fit the existing codebase** — the same patterns, wiring, and test style
as the commands already there, so it looks like it was always part of the library. Keep the suite green
and add a test like the others.

Delegate to `feat.dev` (they own the repo). Verify read-only when they report — does it work *and* does
it match how the rest of the library is written? — then reply to me with a summary and your verification,
only once it's done and verified. Stay in lanes: `feat.dev` touches only its own repo; coordinate by message.
