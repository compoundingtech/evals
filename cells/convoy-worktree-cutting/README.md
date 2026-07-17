# convoy-worktree-cutting — convoy cuts a real linked worktree off the megarepo

**Discriminates:** do `convoy init --megarepo <path>` + `convoy add <id>` cut a **real linked git worktree** off
the megarepo into `<net>/worktrees/<id>` — `.git` a file, branch `convoy/<id>`, both trees clean? (deterministic, held-out)

**Capabilities required:** `claude,convoy,st,pty,git` · run `bin/st-evals preflight`. No LLM — real commands, assert
exact git shape.

## What it proves (Nathan ask + the pollution fix)

The redesign's structural fix for *"don't pollute the user's repo"* is that agents work in a **dedicated git
worktree** cut off the user's megarepo — never in an arbitrary checkout. This cell proves convoy actually cuts that
worktree correctly, per the redesign (#4b, convoy #59):

- `<net>/worktrees/<id>/` exists (convoy add placed the workspace there);
- its `.git` is a **file** — `gitdir: <megarepo>/.git/worktrees/<id>` — a **linked worktree** (shared object
  store), not a directory (which would be a clone);
- it is on branch **`convoy/<id>`** (its own branch, not the megarepo's);
- the megarepo's `git worktree list` **includes it** (a genuine worktree *of* the megarepo);
- **both** the worktree and the megarepo working trees are **clean** — cutting the worktree pollutes neither.

CI/regression guard for the megarepo worktree model. GREEN once #59 lands (it has, @ `36d5cf8`).

## How it works (box-free)

- `fixture/probe.sh` — makes a megarepo (git repo + commit), `convoy init --megarepo`, `convoy add`, then captures
  the worktree's `.git` type + gitdir target + branch + the megarepo's `git worktree list` + both `git status`es,
  and tears down. Records the convoy version.
- `fixture/grade.sh` — hard gates: **WORKTREE-CUT**, **LINKED-NOT-CLONE**, **BRANCH**, **REAL-WORKTREE**,
  **NO-POLLUTION** (worktree + megarepo clean), **MUTATION-VALID** (a bogus id reads absent).

## Run it

`fixture/probe.sh <SB>` then `fixture/grade.sh <SB>`, or `bin/st-evals run convoy-worktree-cutting`. Greenfield-safe;
zero-orphan teardown; never touches the live convoy.

See `task.toml` for the full spec. Reuses the `weird-git-setup` git-worktree layout probes (`.git`-is-a-file,
linked-worktree detection, branch attribution, no-leak). Siblings:
[`convoy-init-structure`](../convoy-init-structure/README.md) + [`convoy-add-structure`](../convoy-add-structure/README.md).
