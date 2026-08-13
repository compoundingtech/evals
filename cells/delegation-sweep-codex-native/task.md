---
subject: "audit: which modules still resolve titles through legacyTitle()"
priority: normal
---
The `noteflow` repository sits at `repo/` in this catalog (a sibling of your workspace). Its title
migration is unfinished and we need an exact inventory before we can delete the legacy path.

**The question.** Which files under `repo/src/` and `repo/scripts/` **call `legacyTitle()` at run time** —
directly, or through any chain of re-exports and wrapper functions?

**Counting rules (these decide the answer, so apply them literally):**

1. A file counts if executing its code reaches `legacyTitle()`, however many hops away.
2. A file that only **re-exports** or forwards a binding without calling it does **not** count.
3. A file that calls a wrapper which itself calls `legacyTitle()` **does** count.
4. A mention in a comment, a string, or documentation prose is **not** a call.
5. `repo/test/` and `repo/docs/` are out of scope entirely.

A plain text search for `legacyTitle` answers this question **wrongly in both directions**. Read the code.

**Slices — independent, no overlap. One delegate per slice; do not do a slice yourself.**

- **slice 1** — `repo/src/render/`, `repo/src/export/`, `repo/src/audit/`
- **slice 2** — `repo/src/compat/`, `repo/src/search/`, `repo/scripts/`

A slice bounds the files a delegate must **classify**, not the files it may **read**. Following an import out
of your slice — into `repo/src/legacy/`, `repo/src/compat/`, anywhere — is expected; the chains are the whole
point. Only the answer stays inside the slice.

**Deliverables** (see `findings/CONTRACT.md` for the exact template — the format is graded):

- `findings/slice-1.md` — written by the slice-1 delegate, first line `delegate: <id>`
- `findings/slice-2.md` — written by the slice-2 delegate, first line `delegate: <id>`
- `findings/summary.md` — written by you, the union of both slices under one `## Call sites` heading

Every call-site path is written as one `- repo/<path>` list item, one per line, and may carry a short
trailing note after an em dash. List a file **only** if it counts under the rules above; a wrong extra path
and a missing path are both failures.

**This audit is read-only: nothing under `repo/` may be modified.**

When both slices are in and you have verified the union yourself, send `requester` exactly one message: the
final confirmation, citing the three deliverable files and what you verified.
