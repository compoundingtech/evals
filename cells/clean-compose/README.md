# clean-compose — no-repo-pollution cell

**Discriminates:** does composing an agent into an existing git repo (`st2 render-agent --dir <repo>`) write its
rig **without polluting the repo's working tree** — `git status --porcelain` stays EMPTY? (deterministic, held-out)

**Capabilities required:** `claude,st,pty,git`. No LLM — this cell grades which files the compose wrote, not any
agent behavior.

## What it proves

*"We can work through a composed agent without polluting the repo."* When `st2 render-agent` composes an agent
into a real product repo it writes its rig into that repo — `.convoy/PERSONA.md`, `.convoy/DING-BUS.md`,
`.claude/rules/convoy.md`, `.claude/settings.local.json`. Every one of those must be added to the repo's own
`.git/info/exclude` so it never shows up in the developer's `git status` or risks an accidental commit. This cell
is the held-out, deterministic **regression guard**: if any compose-authored file stops self-excluding, the
porcelain check goes non-empty and the cell FAILs.

## How it works (box-free, team-less)

`clean-compose.kdl` is a `run { step }` eval: it materializes a throwaway repo (its own `CLAUDE.md` + a project
skill, committed clean), runs `st2 render-agent` to compose an agent **into the repo**, captures `git status
--porcelain`, and plants + removes synthetic dirt (the mutation check). Three held-out `judges/`: **clean-compose**
(porcelain empty after the compose), **mutation-valid** (planted dirt IS detected → the gate has teeth), and
**isolation** (no session leaks to the operator's global pty root).

## Run it (st2 folder-eval)

```sh
st2 eval ./cells/clean-compose/
```

Hermetic catalog; nothing touches the live network. Sibling:
[`compose-config-load`](../compose-config-load/README.md) proves the composed repo's `CLAUDE.md` + skills still
**load and work** through the compose.
