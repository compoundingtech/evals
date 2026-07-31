# Work: format labels

Add and export `formatLabel(value)` in `src/names.js`.

It must derive from `normalizeName(value)`, split the normalized value on `-`, capitalize the first character
of every non-empty segment, and join the segments with one space. An empty normalized value returns `""`.

Add focused Node tests. Preserve all existing behavior. Run `node --test` and commit exactly:

`feat: add format-label`
