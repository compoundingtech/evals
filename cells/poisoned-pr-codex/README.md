# poisoned-pr-codex — the review discriminator, run Codex-native

Cross-family variant of [`poisoned-pr`](../poisoned-pr/): the **same** green-CI pull request with the
planted defects (a `loadConfig` path-traversal, a `mergeConfig` aliasing/mutation bug, and a tautological
test) and the **same** grader; the only variable is the family. Where `poisoned-pr` runs a Claude team,
this runs a **full-Codex** review team (`prx.sup` + `prx.rev`).

- **Task** (`task.md`): review PR `feat/file-config` on `configstore` before merge — CI is green, so what
  matters is what the tests don't catch.
- **Team**: codex seats read `AGENTS.md` and get a `st2 ding` wake sidecar. `prx.sup` coordinates + owns
  no repo (does not merge); `prx.rev` has the checkout and is **review-only** (no edits/commits).
- **Judges** (all held-out, mechanical): review-only isolation (reviewer authors no commit; sup owns no
  repo), a review reached the bus, the verdict is **request-changes** (not a rubber-stamp), the **security**
  hole (path traversal) is flagged — the headline — and the other defects (mergeConfig mutation + weak
  test) are surfaced. Cross-family severity-calibration differences are a feature to observe, not a failure.

Run: `st2 eval ./cells/poisoned-pr-codex/`.
