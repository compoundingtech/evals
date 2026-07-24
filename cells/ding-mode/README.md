# ding-mode — a no-MCP team coordinates over the bus

**What it evaluates.** A team coordinating a real task (implement `slugify` in the `widget` lib) purely over
ding + the st2 CLI — no MCP. A supervisor (`dm.sup`, coordinate-only) delegates to a specialist (`dm.dev`,
owns the repo); the boot ritual, the delegation, and the report all happen over the bus. On st2 the ding-only
path is the *default* (there is no MCP), so this cell verifies the whole `[DING]` loop closes cleanly.

**Run it:** `st2 eval ./cells/ding-mode/`

## The folder

| path | what it is |
| --- | --- |
| `ding-mode.kdl` | the whole eval: the `dm` team (sup + dev) + the `eval {}` block (copy, kickoff, judges) |
| `task.md` | the request delivered to `dm.sup` |
| `fixture/` | `worker/` (the `widget` repo — slugify stub + green suite, owner-pinned `dm.dev`, `_git` → `.git` on copy) + `sup/` (coordinate-only, no repo), each with an `st2`-native persona |
| `judges/` | the held-out bash judges (below) |

## What makes it pass (all judges must pass)

- **isolation** — only `dm.dev` authored; the supervisor owns no repo.
- **no MCP** — neither agent dir has an `.mcp.json` (joined via ding + the st2 CLI).
- **task correct** — `slugify` meets the spec on all held-out cases (run, not eyeballed); suite green; committed.
- **coordination** — the delegate → report → confirm loop closed over the bus.
