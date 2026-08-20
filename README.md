# evals

Isolation-gated, held-out-graded evals for agent teams.

Most agent evals score one model on one task. This corpus scores a supervisor and specialists working through
the native st2 message bus on synthetic software tasks. One frozen instruction starts the scenario; graders the
team never sees verify ownership, coordination, and correctness.

The unit under test is the whole network: st2, pty, the harness commands, personas, team shape, and graders.
The corpus contains Claude, Codex, mixed-family, and model-free cells.

## Authoritative surfaces

- [`AGENT-SPEC.md`](AGENT-SPEC.md) and its maintained acceptance cells are the canonical Agent Spec contract
  and proof surface. The exact st2 pin names the implementation and version the corpus currently proves; st2
  does not own the specification.
- [`CATALOG.md`](CATALOG.md) is the generated current cell inventory, cost view, exclusions, latest accepted
  PASS evidence, and last-run status. [`evidence/run-history.tsv`](evidence/run-history.tsv) is the append-only
  PASS/FAIL ledger with exact commits, model/effort, duration, usage/cost, cleanup, and receipt.
- `cells/<cell>/<cell>.kdl` is the canonical executable definition for one cell.

Do not add another agent spec, readiness ledger, or hand-maintained corpus matrix.

## Product behavior contract

Before changing product behavior, read the approved [vision](docs/vrs/vision.md),
[requirements](docs/vrs/requirements.md), and [specification](docs/vrs/spec.md). Update
`docs/vrs/spec.md` with the implementation. Nathan must explicitly approve changes to the
vision or requirements.

## Safety first

The complete free preflight never starts Claude or Codex:

```sh
bin/check-corpus.sh
```

It enforces the pinned st2 build, shell and KDL parsing, explicit model/effort selection for every provider
command (including commands nested in another launch prompt), absence of retired runtime surfaces,
reproducible fixture resets, the one-drain/DING lifecycle, harness-native loaders and hooks, PII safety, and
an up-to-date generated catalog.

Preview the exact overnight order and cost shape:

```sh
bin/overnight.sh --dry-run
bin/overnight.sh --dry-run --cell ghost-bug --cell ghost-bug-codex
```

Paid execution requires `--run`, a clean `main` worktree, and either one or more explicit `--cell` selections
or separately reviewed `--all`. Repeated selectors preserve CLI order. With no selector, the default dry run
is inventory-only and can never imply a 28-cell paid launch. The conservative default stops before the next
cell on either a hard usage error or an informational reset-available banner:

```sh
bin/overnight.sh --run \
  --cell ghost-bug \
  --cell ghost-bug-codex \
  --state-dir .eval-runs/overnight
```

An explicit selection may include maintained model-free cells; they still execute through st2 and receive the
same cleanup and durable receipts. Claude/Codex binary and authentication checks run only when the selected
subset actually contains work for that provider.

The exact future full-run command must be separately reviewed because it may spend more model quota after an
informational Codex banner:

```sh
bin/overnight.sh --run --all \
  --allow-informational-reset-banner \
  --state-dir .eval-runs/overnight
```

The overnight runner is sequential. Each cell has a declared timeout and watchdog, durable log, and atomic PASS
receipt. A resumed run skips only matching completed receipts. Hard quota/rate-limit errors always write a
`STOPPED` guard. An informational Codex “N usage limit resets available” banner lets that active cell tear down
and record its result first, then stops by default; only the explicit informational-banner opt-in permits the
next paid cell to start.

## Run one cell

`st2 eval` creates a hermetic temporary catalog, copies the fixture, boots declared agents and model judges,
delivers the kickoff, waits for completion or the cell timeout, tears seats down, and runs the held-out judges:

```sh
st2 eval ./cells/ghost-bug/
st2 eval ./cells/ghost-bug/ --keep
```

`--keep` preserves the scratch catalog for inspection after teardown. Successful output ends with:

```text
SCORE: N PASS / 0 FAIL / K gating judges
VERDICT: PASS
```

Requirements are `st2 0.1.0` from source
[`47c4aed`](https://github.com/compoundingtech/st2/commit/47c4aed618dc88413001f6149f2c2bf86a549851),
`pty`, Bash, Git, `jq`, Rust/Cargo for the pinned KDL parser gate, and Node for JavaScript fixtures. A paid cell
also needs every harness named by its dry-run row.

## Cell layout

```text
cells/<cell>/
  <cell>.kdl   team/agents, native ding, fixture copy, kickoff, timeout, run steps, and judges
  fixture/     synthetic repos, harness overlays/hooks, and deterministic setup inputs
  task.md      frozen kickoff content when the cell has a team
  judges/*.sh  held-out graders
  README.md    discriminator and cell-specific notes
```

The eval runner owns `CATALOG`, flat native `ST_ROOT`, and `PTY_ROOT`. Active cell KDL must not author a
compatibility bus path or wake sidecar.

Folder evals intentionally bake Claude or Codex loaders, personas, and canonical or custom hooks into fixture
workspaces copied by `eval { copy ... }`. Those agents execute real hooks through `ST_HOOKS`; mutable personal
defaults are not part of the eval. `bin/check-harness-contract.sh` verifies the canonical files used by every
current bus-connected model agent.

Team-less cells use deterministic `run` steps and judges without a model. Current examples cover native hook
materialization, network health, catalog/pty isolation, and pty send/peek behavior.

## Native Resource-envelope acceptance

`agent-spec-resource-bindings` is the model-free companion to
[`compoundingtech/st2#86`](https://github.com/compoundingtech/st2/pull/86). It exercises native catalog
declarations rather than the tournament's synthetic Resource documents. The cell proves strict envelope
validation, deterministic `st2 agents --json` inspection, URI-scheme-selected downstream profiles, exact URI preservation, and
adoption of a live task after a Resource-only declaration edit.

Folder-eval Resource projection, Resource resolution, access, readiness, and lifecycle policy are outside this
cell. The portable Agent Spec envelope does not imply any of them.

## Resource-binding tournament

The nine `assignment-contract-*` cells form one matched tournament over three lifecycle scenarios and three
Agent Spec treatments. The kickoff and product task are treatment-neutral; only the experimental durable
declaration and its resolver rules differ.

| Scenario | Direct named resources | Resources plus `focus` | Resources plus `assignment` |
| --- | --- | --- | --- |
| Cold discovery | One `work` binding selects the issue | `focus` selects an `intent` binding | An Assignment groups four bindings |
| Hot retarget | Rebind `work`, then remove it | Rebind focused `intent`, then remove `focus` | Replace the active Assignment, then make it idle |
| Handoff/restart | Remove A's `work`, then add B's | Remove A's focus, then focus B | Make A idle, then activate B |

The selected contract is the direct-resource treatment: the resource URI is identity, its scheme selects
the downstream profile, and the KDL name is the binding's semantic role. An agent has zero or one direct `work`
binding; zero means idle. A handoff publishes `A -> no holder -> B`. The Focus and Assignment treatments remain
as controls, not proposed product layers. Required/optional and access semantics are intentionally outside
this tournament.

Exploratory Codex E2E runs on 2026-07-30 completed the intended behavior in all nine cells. Three original
graders produced false negatives: abbreviated commit evidence in cold Focus, message cardinality in hot Focus,
and terminal ordering in resource-only handoff. The checked-in graders accept the preserved correct behavior
and include model-free regression tests for those oracle boundaries. These pre-publication runs are design
evidence, not accepted corpus receipts; `CATALOG.md` remains authoritative and will show no accepted PASS until
a committed cell is rerun.

## Add or change a cell

1. Create exactly one `cells/<name>/<name>.kdl`.
2. Give it exactly one `max-timeout`.
3. Pin every Claude launch to `claude-sonnet-5 --effort medium` and every Codex launch to
   `gpt-5.6-sol` with medium reasoning effort. This includes model judges.
4. Use native bare `ding` for each bus-connected model agent. Teach one cold-start inbox drain; when empty,
   stand by for DING, then drain once again, act, archive, and report over the bus.
5. Materialize the harness contract in every model workspace. Claude loads `PERSONA.md` through `CLAUDE.md`
   and uses the canonical `.claude/settings.local.json`; Codex loads `AGENTS.md`, uses the canonical
   `.codex/hooks.json`, and launches with hook trust enabled.
6. Keep the fixture synthetic. Freeze checked-in repositories as `_git`, or build absolute-path topologies in a
   deterministic pre-boot materializer.
7. Add held-out checks that accept any correct implementation but reject a deliberately wrong one. Attribute
   writes before grading behavior.
8. Run `bin/check-corpus.sh`. Run the paid cell only when explicitly authorized.
9. Regenerate the sole catalog surface with `bin/generate-catalog.sh --write`.

## Public boundary

This repository contains public synthetic scenarios and structured run provenance, not private network state.
`bin/check-no-pii.sh` rejects machine-specific paths and configured private tokens before publication,
including content reachable only through a fixture's published `_git` history. Its dirty/clean history
controls run in the complete free preflight.

MIT licensed; see [`LICENSE`](LICENSE).
