# launch-method-selection

Contract-first, model-free acceptance coverage for the proposed start/resume launch-method shape discussed in
[`compoundingtech/st2#124`](https://github.com/compoundingtech/st2/issues/124). The field names and defaults are
not ratified. This cell therefore remains proposal-tracking evidence and does not update `AGENT-SPEC.md`.

The four proposed cases are expected product reds while the current st2 grammar exposes one top-level `argv`.
The legacy case is a positive control and must keep passing. Expected reds are classified evidence, never
conformance passes.

**Capabilities required:** `st2,pty,jq,awk,grep,sed,coreutils`. No model or provider. Every catalog, synthetic
session record, workspace, durable marker, process, and PTY root lives below the eval-owned temporary catalog.

## Closed-set cases

| Case | Current result | Discriminator |
| --- | --- | --- |
| `explicit-start-new-session` | `RED/P01` | selects `start`, creates one new synthetic native ID, and preserves durable work |
| `explicit-resume-exact` | `RED/P01` | appends parsed conversation records only to the declared ID, never a newer neighbor |
| `unavailable-refuse` | `RED/P01` | refuses before either method launches or any session record changes |
| `unavailable-start` | `RED/P01` | selects `start` only when that unavailable fallback is declared |
| `legacy-single-argv` | `PASS` | preserves the existing single top-level `argv` launch behavior |

`P01` means the proposed grammar is unavailable. Once a candidate parses it, behavioral failures are classified
as `P02` wrong method, `P03` wrong session, `P04` wrong unavailable policy, `P05` lost durable continuity, or
`P06` leaked eval-owned runtime state.

The checked-in `AGENT-SPEC.md` remains pinned to an older portable runner and documents compact `command`.
Current st2 declarations use one top-level `argv`; this proposal replaces that cardinality invariant with a
successor that accepts either one legacy `argv` or launch methods, never an ambiguous mixture.

## Evidence boundary

The adapter writes synthetic JSONL conversation records and checks them by parsed `sessionId` and record type.
It never infers continuity from file bytes or mtime. It does not call Claude or Codex and does not touch their
homes or transcript stores. Provider-native facts remain the version-scoped evidence recorded on st2#124;
this cell covers only provider-neutral selection and refusal.

The candidate preserves the optional `resume.session` pin in its public Rust `agent-spec` model, but the
current versioned `agents`/`tasks` CLI and launch receipts do not project it. This external behavior cell can
therefore prove that the selected resume argv continues the exact adversarially chosen session, but it cannot
independently prove parser-level pin preservation. The upstream model tests own that assertion until a public
wire surface is deliberately versioned; this cell does not invent one.

`judges/self-test.sh` plants missing-case, duplicate-case, false-promotion, unknown-gap, false-honesty, and
cleanup-receipt mutations. The focused run remains red until every proposed case passes and the closed-set
manifest is updated.

```sh
bash ./cells/launch-method-selection/judges/self-test.sh
st2 eval ./cells/launch-method-selection/ --keep
```
