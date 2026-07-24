# migration — a breaking dependency upgrade, at quality

**What it evaluates.** A real dependency migration done well — mechanical breadth without silently dropping
cases. The `meeting-notes` app depends on a vendored `greetkit@1.0.0`; `2.0.0` (source + CHANGELOG in-repo
at `lib/greetkit-2.0.0/`) ships breaking changes: `greetAll` is **removed**, `farewell` → `goodbye`
(output `.` → `!`), `greetFormal(name, title)` → `greetFormal({ name, title })`, and `greet` is unchanged
(a control). A supervisor (`mig.sup`, coordinate-only) delegates to a specialist (`mig.dev`, owns the repo)
to get fully onto 2.0.0. The traps: **breadth** (fix every call site), **judgment** (leave the unchanged
`greet` alone), and — the part a lazy "make it green" migrant fails — **not dropping cases**: when
`greetAll` disappears, the app's batch-greeting capability (`welcomeTeam`) must be **reimplemented** with
`names.map`, not deleted; and changed assertions must be **updated, not weakened**.

**Run it:** `st2 eval ./cells/migration/`

`st2 eval` copies the fixture into a fresh catalog, boots the team, delivers `task.md` to `mig.sup`, runs
to the supervisor's confirmation (or `max-timeout`), then runs the judges → verdict.

## The folder

| path | what it is |
| --- | --- |
| `migration.kdl` | the whole eval: the `mig` team (sup + dev) + the `eval {}` block (copy, kickoff, judges) |
| `task.md` | the upgrade request delivered to `mig.sup` |
| `fixture/` | the pre-built world, copied 1:1: `worker/` (the `meeting-notes` repo — green suite against 1.0.0, 2.0.0 staged in `lib/`, owner-pinned author `mig.dev`, git db `worker/_git` → `.git` on copy) and `sup/` (coordinate-only, no repo). Each holds an `st2`-native persona. |
| `judges/` | the held-out bash judges (below) |

## What makes it pass (all judges must pass — the team never sees these)

- **isolation** (`judges/isolation.sh`) — only `mig.dev` authored; the supervisor owns no repo.
- **visible suite** (`judges/suite.sh`) — `node --test` green after the migration.
- **batch preserved** (`judges/batch-preserved.sh`) — **the discriminator**: `welcomeTeam(['X','Y'])`
  still returns `['Hello, X!','Hello, Y!']` (the removed `greetAll` capability was reimplemented, not dropped).
- **full migration** (`judges/full-migration.sh`) — greetkit really on 2.0.0, no `greetAll` call, no v1
  names imported, every `greetFormal` on the object-arg form, imported greetkit exports no v1 API.
- **tests not weakened** (`judges/tests-not-weakened.sh`) — count kept (≥6), no `.skip`/`.todo`/`ok(true)`,
  signoff still asserts a concrete Goodbye, `welcomeTeam` still tested.
