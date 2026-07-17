# convoy-init-narration — convoy init is narrated for a first-timer

**Discriminates:** does `convoy init` **tell the user what's happening, step by step** (default), stay **silent
under `--quiet`**, and emit a **one-line `--json` summary**? (deterministic, held-out)

**Capabilities required:** `convoy,st,pty,git` · run `bin/st-evals preflight`. No LLM — real command, grep the output.

## What it proves (Nathan ask)

Both `convoy init` and `convoy doctor` must be **chatty/narrated** so a brand-new user (Johannes) can follow along
and trust the setup. This is the guard that the narration is actually **there** — and that `--quiet`/`--json` still
work for scripts and evals. It's a **light presence check**, not an LLM judge of the prose (redesign #5, convoy #60).

## How it works (box-free)

- `fixture/probe.sh` — runs the real `convoy init` in three modes on isolated paths (default / `--quiet` / `--json`),
  captures stdout, and tears down.
- `fixture/grade.sh` — hard gates:
  - **DEFAULT NARRATION**: substantial step narration (≥5 lines) mentioning the network structure, the `convoy.toml`
    config, completion, and the **"run `convoy doctor`"** next-step pointer (tolerant substrings, not exact prose).
  - **`--quiet`**: **zero** stdout lines (scriptable silent mode).
  - **`--json`**: exactly **one** line whose object has `{network,dir,stRoot,ptyRoot,worktrees}`.
  - **MUTATION-VALID**: a not-present phrase reads absent (the grep genuinely discriminates); the `--quiet`=0-lines
    vs default=narrated contrast is the built-in mutation.

## Run it

`fixture/probe.sh <SB>` then `fixture/grade.sh <SB>`, or `bin/st-evals run convoy-init-narration`. Greenfield-safe;
isolated paths; zero-orphan teardown.

See `task.toml` for the full spec. Complements
[`convoy-init-structure`](../convoy-init-structure/README.md) (the on-disk layout `init` creates). The last piece —
a `convoy doctor` narrated structure-correct + can-work cell (#6) — follows when convoy-claude lands it.
