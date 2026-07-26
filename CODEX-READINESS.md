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
| [`fork-in-the-road-codex.kdl`](https://github.com/compoundingtech/evals/blob/dc7ad3abd8d13fb2e9e2920d15e69ef0a23d0819/cells/fork-in-the-road-codex/fork-in-the-road-codex.kdl) | Four-seat option generation, debate, privacy judgment, and escalation | Complete `AGENTS.md` files intentionally pre-seeded; four frozen `_git` workspaces rehydrate cleanly | Both gates print `PASS` | **Pending current-build smoke**; high, approximately 12–25 minutes |

The minimum remaining paid proof is exactly one run under the bounded authorization that followed the
usage-warning disclosure:

```sh
st2 eval ./cells/fork-in-the-road-codex/ --keep
```

Success means `VERDICT: PASS` with 5/5 gating fork-in-the-road judges green. Do not run any additional
cell and do not retry without a concrete diagnosed fix.

## Claude reference subset and honest gap

Two immutable, historically run-validated Claude KDLs cover representative shapes:

| KDL | What it teaches | Cheap evidence | Model-backed command |
|---|---|---|---|
| [`ding-reply.kdl` at its 2/2 PASS conversion](https://github.com/compoundingtech/evals/blob/7a063abfcc10b53a18d71bdabb0c478161694650/cells/ding-reply/ding-reply.kdl) | One Claude agent, fixture-preseeded `CLAUDE.md` → `PERSONA.md`, and an exact threaded CLI reply without MCP | `git diff --exit-code 7a063abfcc10b53a18d71bdabb0c478161694650..HEAD -- cells/ding-reply/ding-reply.kdl` succeeds with no diff; `bash -n cells/ding-reply/judges/*.sh` exits 0 | `st2 eval ./cells/ding-reply/ --keep`; historical success is 2/2 PASS, current run not authorized |
| [`team-standup.kdl` at its 4/4 PASS conversion](https://github.com/compoundingtech/evals/blob/d76f6d4b05968bd0c1694bab30d87fec8edcb8f3/cells/team-standup/team-standup.kdl) | One initial Claude CoS dynamically creates a specialist with the older `st2 render-agent` + `st2 up --once` flow | `git diff --exit-code d76f6d4b05968bd0c1694bab30d87fec8edcb8f3..HEAD -- cells/team-standup/team-standup.kdl` succeeds with no diff; `bash -n cells/team-standup/judges/*.sh` exits 0 | `st2 eval ./cells/team-standup/ --keep`; historical success is 4/4 PASS, current run not authorized |

These Claude cells are historical references, not current native-only examples: both still author the
legacy `smalltalk` bus root and explicit ding sidecars. The corpus currently contains no Claude
folder-eval KDL using the current declarative `render {}` form. The supported native examples are
therefore the Codex KDLs above; native declarative-render Claude coverage remains an explicit future
conversion and current-build validation gap.
