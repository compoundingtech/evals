# Work: normalize names

Add and export `normalizeName(value)` in `src/names.js`.

It must:

- convert the input with `String(value)`;
- trim leading and trailing whitespace;
- lowercase the result; and
- replace each run of internal whitespace with one `-`.

Add focused Node tests. Preserve all existing behavior. Run `node --test` and commit exactly:

`feat: add normalize-name`
