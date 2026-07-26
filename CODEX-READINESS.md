# Codex-native readiness ledger

This ledger is the executable handoff for the five-cell Codex tranche. The completed non-paid source
state is pinned to immutable evals commit
[`9cae486aafb2ef9bbb6766db6657b294922b65e2`](https://github.com/compoundingtech/evals/commit/9cae486aafb2ef9bbb6766db6657b294922b65e2).
Exact paid-run rows live in [`HARNESS-MATRIX.md`](HARNESS-MATRIX.md); each pushed evidence report pins
the corresponding ledger commit.

## Free acceptance

Run both deterministic gates before opting into a model-backed smoke:

```sh
bin/check-codex-native.sh
bin/check-codex-reset.sh
```

The native gate rejects legacy bus declarations and non-Codex commands, requires one native `ding` per
seat, and proves every workspace receives a non-empty `AGENTS.md`. The reset gate constructs two fresh
copies of every fixture, rehydrates frozen `_git` repositories or runs the dynamic materializer, and
requires matching persona/Git manifests, valid clean repositories, and catalog-local remotes.

These checks are static and free. They do not start a model. `st2 validate` validates a rendered agent
catalog, not a folder-eval KDL, so the authoritative KDL/runtime proof remains an opt-in `st2 eval`.

## Five-cell status

| Cell | Shape and lesson | Persona and reset path | Static/free success | Opt-in live status and cost |
|---|---|---|---|---|
| [`license-mit-codex.kdl`](https://github.com/compoundingtech/evals/blob/dc7ad3abd8d13fb2e9e2920d15e69ef0a23d0819/cells/license-mit-codex/license-mit-codex.kdl) | Two-subject delegate → execute → verify → confirm loop plus a short model judge | Complete `AGENTS.md` files intentionally pre-seeded; frozen `worker/_git` rehydrates in a fresh catalog | Both gates print `PASS` | **6/6 PASS**, st2 `9d26245`, 1m39s; low cost |
| [`signal-rename-codex.kdl`](https://github.com/compoundingtech/evals/blob/dc7ad3abd8d13fb2e9e2920d15e69ef0a23d0819/cells/signal-rename-codex/signal-rename-codex.kdl) | Four-seat ownership, sequencing, compatibility window, and held-out cross-package E2E | `materialize.sh` rebuilds the bare origin and four clones, then installs each clone's `AGENTS.md` | Both gates print `PASS` | **6/6 PASS**, st2 `9d26245`, 8m07s; high cost |
| [`ghost-bug-codex.kdl`](https://github.com/compoundingtech/evals/blob/dc7ad3abd8d13fb2e9e2920d15e69ef0a23d0819/cells/ghost-bug-codex/ghost-bug-codex.kdl) | Two-seat root-cause debugging with a mutation-valid regression | Complete `AGENTS.md` files intentionally pre-seeded; frozen `worker/_git` rehydrates cleanly | Both gates print `PASS` | **5/5 PASS**, st2 `9d26245`, 1m38s; medium cost. Both seats then showed a usage-limit notice, so later model runs stopped |
| [`poisoned-pr-codex.kdl`](https://github.com/compoundingtech/evals/blob/9cae486aafb2ef9bbb6766db6657b294922b65e2/cells/poisoned-pr-codex/poisoned-pr-codex.kdl) | Two-seat review-only security judgment despite green CI | Complete `AGENTS.md` files intentionally pre-seeded; frozen `rev/_git` rehydrates cleanly | Both gates print `PASS` | **4/4 gating PASS** plus non-gating defect signal, st2 `25d8371`, 1m52s; medium cost |
| [`fork-in-the-road-codex.kdl`](https://github.com/compoundingtech/evals/blob/9cae486aafb2ef9bbb6766db6657b294922b65e2/cells/fork-in-the-road-codex/fork-in-the-road-codex.kdl) | Four-seat option generation, debate, privacy judgment, and escalation | Complete `AGENTS.md` files intentionally pre-seeded; four frozen `_git` workspaces rehydrate cleanly | Both gates print `PASS` | **5/5 PASS**, st2 `25d8371`, 7m21s; one retry after a concrete missing-optional-archive grader diagnosis and fix |

The five-cell tranche is current-build complete. No additional model-backed run is part of this ledger;
the bounded authorization is exhausted.

## Claude-native examples

The maintained simple and coordinated Claude examples, their persona/render/reset mechanisms, free
acceptance commands, historical provenance, and current live-proof gap are tracked separately in
[`CLAUDE-NATIVE-READINESS.md`](CLAUDE-NATIVE-READINESS.md).

`ding-reply` and `signal-rename` now use current native bare `ding` with no authored compatibility bus
root or wake sidecar. `team-standup` remains a legacy retired-render-CLI reference and is not presented
as current.
