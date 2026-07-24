---
subject: "small task: implement slugify in the widget lib"
priority: high
---
We need a `slugify(text)` helper in the `widget` lib (the repo your specialist `dm.dev` owns). Please have it
implement `slugify` in `src/slug.js` to the spec written in that file:

  - lowercase the text,
  - trim leading/trailing whitespace,
  - replace every run of non-alphanumeric characters with a single dash,
  - strip any leading/trailing dashes.

So `"Hello World"` -> `"hello-world"`, `"Foo_Bar Baz"` -> `"foo-bar-baz"`, `"  Trim Me  "` -> `"trim-me"`,
`"A.B.C"` -> `"a-b-c"`, `"Rock & Roll!"` -> `"rock-roll"`. Keep the test suite green (`npm test`) and commit.

You're the supervisor: delegate this to `dm.dev`, await its report, then verify read-only that slugify meets
the spec and the suite is green, and confirm back to me — only once it's done. Stay in lanes: `dm.dev` touches
only its own repo; coordinate by message.
