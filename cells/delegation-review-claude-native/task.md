---
subject: "review: proposed change to noteflow (review/proposed.patch)"
priority: high
---
A contributor proposed the change in `review/proposed.patch` against the `noteflow` repository at `repo/`
in this catalog (a sibling of your workspace). We need an independent review before it merges.

**The suite is green with the patch applied.** Whatever is wrong with it, the tests do not catch it.

**What counts as a defect:** a change that makes the code behave incorrectly for some input, or that
introduces state corruption. Some hunks in this patch look unusual but are **correct** — a rewrite that
preserves behavior is not a defect, and a test that changes shape while covering strictly more is not a
defect. **Reporting a correct change as a defect is a false positive and fails this review.**

**Slices — independent, no overlap. One delegate per slice; do not review a slice yourself.**

- **slice 1** — hunks touching `repo/src/export/` and `repo/src/util/`
- **slice 2** — hunks touching `repo/src/search/`, `repo/src/sort.js`, and `repo/test/`

A slice bounds the hunks a delegate must **judge**, not what it may **read**: reading the whole patch and the
whole repository for context is expected. Each delegate judges only its own slice, and must not be told what
the other delegate found.

**Deliverables** (see `findings/CONTRACT.md` for the exact template — the format is graded):

- `findings/review-1.md` — written by the slice-1 delegate, first line `delegate: <id>`
- `findings/review-2.md` — written by the slice-2 delegate, first line `delegate: <id>`
- `findings/summary.md` — written by you, listing every defect from both slices under one `## Defects`
  heading

Each defect is one `- repo/<path> — <one sentence naming the mechanism>` list item. Name the mechanism
concretely (what breaks, for which input); a bare path with no mechanism does not demonstrate a review.

**This review is read-only: nothing under `repo/` may be modified.** You may copy the repository elsewhere
if you want to run anything.

When both reviews are in and you have verified them yourself, send `requester` exactly one message: the
final confirmation, citing the three deliverable files, the defect count, and what you verified.
