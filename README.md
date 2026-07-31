# evals

Isolation-gated, held-out-graded evals for agent teams.

Most agent evals score one model on one task. This corpus scores a supervisor and specialists working through
the native st2 message bus on synthetic software tasks. One frozen instruction starts the scenario; graders the
team never sees verify ownership, coordination, and correctness.

The unit under test is the whole network: st2, pty, the harness commands, personas, team shape, and graders.
The corpus contains Claude, Codex, mixed-family, and model-free cells.

## Authoritative surfaces

- [`AGENT-SPEC.md`](AGENT-SPEC.md) is the sole hand-authored st2 agent specification, pinned to the exact
  stabilization commit.
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
delivers the kickoff, waits for completion or the cell timeout, tears agents down, and runs the held-out judges:

```sh
st2 eval ./cells/ghost-bug/
st2 eval ./cells/ghost-bug/ --keep
```

`--keep` preserves the scratch catalog for inspection after teardown. Successful output ends with:

```text
SCORE: N PASS / 0 FAIL / K gating judges
VERDICT: PASS
```

Requirements are the immutable `st2 0.1.0+c6846f6` Nix package for source
[`c6846f6239329f0803142afc06c15a07b93937c1`](https://github.com/compoundingtech/st2/commit/c6846f6239329f0803142afc06c15a07b93937c1):
source `flake.lock` byte SHA256
`aa547f85b21a8a8787adaa9f2a3ad37d55246d355248388e2ec38bd85a830141`, output
`/nix/store/z4wj1y20wq00n02gpknnz45fdi2kyc7h-st2-0.1.0`, NAR
`sha256-w3OSHKt96U0aWMzW2FHom6Ii1NvikdXqmJ6wJ1xGJNA=`, and executable SHA256
`25276f30a9cfb287e1a9f72318fada2936402343e958160d46a0a7270ab2db2b`.
The preflight ignores ambient `st2` selection and verifies this full provenance chain before using the
packaged binary. It also requires Nix, `pty`, Bash, Git, `jq`, Rust/Cargo for the pinned KDL parser gate, and
Node for JavaScript fixtures. A paid cell also needs every harness named by its dry-run row.

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
