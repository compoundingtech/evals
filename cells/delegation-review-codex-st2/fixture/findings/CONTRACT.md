# deliverable contract — proposal review

Three files land in this directory, and a coordinator whose persona requires a delegation log
writes that log here too, as `delegation-log.md`. Nothing else in this directory is read by the graders.

## findings/review-<n>.md

```text
delegate: <the identity of the delegate that wrote this file>
slice: <n>

## Defects
- repo/src/example/one.js — <one sentence: what breaks, for which input>

## Cleared
- repo/src/example/two.js — <why this suspicious-looking hunk is actually correct>
```

## findings/summary.md

```text
## Defects
- repo/src/example/one.js — <one sentence naming the mechanism>

## Notes
<the coordinator's verification>
```

Rules:

- One defect per list item, starting with `- `, catalog-relative path first, then ` — ` and the mechanism.
- A file with no real defect belongs under `## Cleared`, never under `## Defects`.
- `summary.md` lists the union of the defects found by every slice, and nothing else.
