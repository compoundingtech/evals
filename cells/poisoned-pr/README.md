# poisoned-pr — review an adversarial PR, catch what CI can't

**What it evaluates.** Code review at quality — catching defects a green CI misses and delivering a
justified **request-changes**, not a rubber-stamp. The PR `feat/file-config` on `configstore` adds
file-based config loading and passes CI, but carries three planted defects: a **path-traversal security
hole** (`loadConfig()` joins an un-sanitized name onto the config dir — the headline), a **correctness
aliasing bug** (`mergeConfig()` mutates its `base` argument), and a **test-quality trap** (the new test
is tautological and `loadConfig` is entirely uncovered). A supervisor (`pr.sup`, coordinate-only)
delegates a review to a reviewer (`pr.rev`, has the checkout). The outcome is **findings + a verdict on
the bus** — the repo is not modified (review-only).

**Run it:** `st2 eval ./cells/poisoned-pr/`

`st2 eval` copies the fixture into a fresh catalog, boots the team, delivers `task.md` to `pr.sup`, runs
to the supervisor's confirmation (or `max-timeout`), then runs the judges → verdict.

## The folder

| path | what it is |
| --- | --- |
| `poisoned-pr.kdl` | the whole eval: the `pr` team (sup + rev) + the `eval {}` block (copy, kickoff, judges) |
| `task.md` | the review request delivered to `pr.sup` |
| `fixture/` | the pre-built world, copied 1:1: `rev/` (the `configstore` checkout on `feat/file-config`, green CI, git db `rev/_git` → `.git` on copy) and `sup/` (coordinate-only, no repo). Each holds an `st2`-native persona. |
| `judges/` | the held-out judges (below); `_review-text.sh` is a sourced helper that aggregates the review off the bus |

## What makes it pass (all judges must pass — the team never sees these)

- **isolation / review-only** (`judges/isolation.sh`) — the reviewer authored no commit and modified no
  code; the supervisor owns no repo.
- **review produced** (`judges/review-exists.sh`) — findings + a verdict reached the bus (or `REVIEW.md`).
- **verdict** (`judges/verdict.sh`) — **request-changes** (approving a PR with a path traversal is the
  exact rubber-stamp this cell fails).
- **SECURITY caught** (`judges/security-caught.sh`) — **the headline**: the review flags the `loadConfig`
  path traversal. Missing it fails the run.
- **other defects** (`judges/other-defects.sh`) — non-gating signals: the `mergeConfig` mutation + the
  weak test / missing coverage.
