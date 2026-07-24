# weird-git-setup — an agent gets working in a megarepo worktree layout

An agent is stood up **inside a linked git worktree** — not a plain clone — and must figure out its git context
and get productive despite it. This is the layout people actually run (a **bare canonical repo + linked
worktrees**), and it's the acceptance test for the launch-into-a-worktree path.

## What's "weird" (the traps a naive agent hits)

- **`.git` is a FILE**, not a directory (a `gitdir:` pointer into the bare repo's `worktrees/<name>/`).
- The **object store lives elsewhere** (the bare repo), shared across worktrees; `--show-toplevel`/`--git-dir`
  return non-obvious, non-cwd paths.
- Each worktree is **pinned to a branch** — a commit must land on **this** worktree's branch (`feature`), not the
  bare repo, not the sibling `wt/main`.
- Linked worktrees **share config** (the fixture enables `extensions.worktreeConfig` for distinct per-worktree
  authors — itself a weird-git detail).

The **persona says nothing about worktrees** — figuring out the git setup is the discriminator.

## The task + the discriminator

`clampkit` has a planted bug (an above-range value clamps to `lo` instead of `hi`) and a RED test. The agent must
root-cause it, add a regression test, keep `node --test` green, and **commit on `feature`**. The grader's
held-out check: the fix is on `feature` (ahead of the seed, authored by the worktree's author) with the suite
green, **and `main` (bare + sibling) is unchanged** — a naive agent that mishandles the layout commits nowhere
useful or leaks into main. **Headline: autonomy — 0 rescues.**

## Run it (st2 folder-eval)

```sh
st2 eval ./cells/weird-git-setup/      # copy fixture → materialize the megarepo → boot wg.dev in wt/feature → judge
```

The whole eval is `weird-git-setup.kdl`. Because a linked worktree's `.git` file holds an **absolute** `gitdir:`
pointer, the megarepo can't be shipped as a static fixture (a `copy` + `_git→.git` can't preserve the
bare↔worktree linkage) — so `fixture/setup-megarepo.sh` runs as the eval's `run { step "materialize" }` to build
the bare canonical + two linked worktrees + the planted bug **in place** in `$CATALOG`, **before** the single
worker (`wg.dev`, workspace `./wt/feature`) boots. Five held-out `judges/` grade the result: worktree resolved ·
suite green · fix committed on `feature` by the worktree's pinned author · no cross-worktree/repo leak · a
regression test committed. Caps: `claude,st,pty,git,node`. Proven live: 6/6 PASS. Design:
`WEIRD-GIT-SETUP-DESIGN.md` (private evals repo).
