# GitHub issue: normalize widget labels

URI: `github-issue://eval/widget-normalization`

Deliver the change in two sequential commits. Complete only the first incomplete phase.

Phase 1:

- add `src/normalize.js`;
- export `normalizeLabel(label)`, which converts its input to a string, trims leading and trailing whitespace,
  and collapses each internal whitespace run to one ASCII space;
- do not change any other tracked product file;
- verify the helper directly; and
- commit with subject `feat: add label normalization` and body trailer `Eval-Worker: arh.a`.

Phase 2:

- preserve the phase-1 commit;
- update `src/widget.js` to import and apply `normalizeLabel` before rendering;
- add `test/widget.test.js` covering trimmed and collapsed labels as well as the existing ordinary-label result;
- add `"type": "module"` and `"scripts": { "test": "bun test" }` to `package.json` without changing its other
  metadata;
- run `bun test`;
- checkpoint after the implementation and tests are ready but before committing; and
- commit with subject `feat: normalize widget labels` and body trailer `Eval-Worker: arh.b`.

Acceptance:

- exactly one phase-1 commit by the first holder precedes exactly one phase-2 commit by the successor;
- `widget("  hello   world  ")` returns `[ hello world ]`;
- `widget("ok")` still returns `[ ok ]`;
- tests pass and the repository is clean; and
- every progress and completion report cites this exact URI.
