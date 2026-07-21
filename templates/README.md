# templates — scaffold a new eval cell

Copy-me starting points for authoring a cell, so a new one lands on the framework's conventions
(isolation gate, hermetic kick, held-out grader) without cargo-culting an existing cell by hand.

```
templates/
  README.md            you are here
  AUTHORING.md         the worked example — author a cell end-to-end, narrated
  cell/                copy this whole dir to cells/<name>/ and replace every TODO(...)
    task.toml          the spec (all fields + inline guidance)
    README.md          the cell's human page (discriminator + how to run)
    fixture/
      setup-sandbox.sh deterministic synthetic-world builder (git-init + PINNED author)
      kick.md          the single hermetic instruction
      grade.sh         the held-out judge (real-state checks, exit-code verdict)
      spin.sh          team-cell launcher (convoy init → compose → add → seed); OMIT for deterministic cells
```

## Quick start

```sh
cp -R templates/cell cells/<name>
# fill in every TODO(...) in cells/<name>/ (start with AUTHORING.md open beside you)
$EDITOR cells/<name>/task.toml cells/<name>/fixture/*
# register it (SORTED position) — both files:
#   cells.manifest  →  <name> | <type> | <ship|flag> | <caps> | <discriminator>
#   REGISTRY.md     →  the human catalogue row
bin/evals preflight        # confirm <name> shows up as runnable with your caps
```

The template lives **outside** `cells/` on purpose: `bin/smoke-setup.sh` globs `cells/*/` and executes
every `setup-sandbox.sh` it finds, so a skeleton under `cells/` would run half-filled and break the smoke
suite. Preflight/list are manifest-driven, so `templates/` never appears in the catalogue.

See **AUTHORING.md** for the full walkthrough and the rules that make a grader honest.
