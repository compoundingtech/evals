# deliverable contract — title call-site audit

Three files land in this directory, and a coordinator whose persona requires a delegation log
writes that log here too, as `delegation-log.md`. Nothing else in this directory is read by the graders.

## findings/slice-<n>.md

```text
delegate: <the identity of the delegate that wrote this file>
slice: <n>

## Call sites
- repo/src/example/one.js — reaches legacyTitle through <how>
- repo/src/example/two.js
```

## findings/summary.md

```text
## Call sites
- repo/src/example/one.js
- repo/src/example/two.js

## Notes
<the coordinator's verification: how the union was checked>
```

Rules:

- One path per list item, starting with `- `, path first, optional ` — note` after it.
- Paths are catalog-relative (`repo/src/...`).
- A slice file lists only its own slice's call sites. `summary.md` lists the union of every slice.
