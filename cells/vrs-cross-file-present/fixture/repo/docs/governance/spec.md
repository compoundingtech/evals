# retry preset implementation map

`config/defaults.json` stores deployable defaults, `config/schema.json` admits only supported names,
`src/retry-presets.js` resolves immutable records, and `docs/config.md` explains operator-visible behavior.
Adding a preset is complete only when all four representations and a regression test agree.

