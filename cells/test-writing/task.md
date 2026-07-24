---
subject: "write a real test suite for the grades module"
priority: high
---
The `grades` module (the repo your author `tw.dev` owns) has **no tests** and we want to lock down its
behavior before we build on it. Please get it a proper test suite.

The bar isn't "green" — it's a suite that would **actually catch a regression**: if someone later
changed a grade cutoff, flipped a comparison, broke the GPA mapping, or messed up the summary math, a
test should go red. So it needs to pin the **exact** behavior — real values, the **boundary** cases (the
exact cutoffs and the edges of the valid range), the **edge** cases, and the **error paths** (what
should throw) — not just run each function once and check it returns something.

It's a test-writing task: the code is believed correct, so **don't change `src/`** — write tests. (If
`tw.dev` genuinely finds a real bug, have them report it rather than edit the code.) Keep it green and commit.

Delegate to `tw.dev` (they own the repo). Verify read-only when they report — would these tests catch a
break, or are they shallow? — then reply to me with a coverage summary and your verification, only once
it's done. Stay in lanes: `tw.dev` touches only its own repo; coordinate by message.
