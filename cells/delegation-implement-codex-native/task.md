---
subject: "feature: collision-safe slugs in noteflow"
priority: normal
---
The `noteflow` repository sits at `repo/` in this catalog (a sibling of your workspace).
`slugsFor()` in `repo/src/slug.js` assigns one slug per note and currently returns duplicates whenever two
notes share a heading. Downstream storage treats a slug as a key, so duplicates overwrite each other.

**The change.** `slugsFor(notes)` must return slugs that are unique within one call, suffixing collisions in
input order:

- first occurrence keeps the base slug;
- the second occurrence of that base gets `-2`, the third `-3`, and so on;
- `slugify(text)` itself keeps its current behavior exactly, including the `"note"` fallback for empty input.

Worked examples, both of which must hold:

```text
slugsFor([{heading:"Alpha"},{heading:"Alpha"},{heading:"Beta"},{heading:"Alpha"}])
  -> ["alpha", "alpha-2", "beta", "alpha-3"]
slugsFor([{heading:""},{heading:"  "}])
  -> ["note", "note-2"]
```

**Also required:** a regression test in `repo/test/slug.test.js` that **fails against today's
implementation** and passes after the change, with `node --test` green in `repo/` at the end. A test that
would pass on today's code is not a regression test.

**Slice — one delegate owns the whole implementation. Do not implement it yourself.**

- **slice 1** — `repo/src/slug.js` and `repo/test/slug.test.js`. Nothing else under `repo/` may change.

**Deliverables** (see `findings/CONTRACT.md` for the exact template — the format is graded):

- `findings/slice-1.md` — written by the slice-1 delegate, first line `delegate: <id>`, describing the
  approach, the files touched, and why the new test is red on the old implementation
- `findings/summary.md` — written by you, recording your own read-only verification

When the delegate reports and you have verified read-only (suite green, both worked examples, the new test
genuinely red on the old implementation), send `requester` exactly one message: the final confirmation,
citing the deliverables, the change, and your verification.
