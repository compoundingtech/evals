# Complex VRS usefulness design — 2026-07-30

Status: preregistered design approved; model-free oracle and mutation checks are
part of the complete corpus preflight. Paid model outcomes are recorded
separately after execution.

## Why the legacy cells were superseded

The eight prior VRS cells did not distinguish useful architectural reasoning:

| Pair | Actual behavioral signal | Confound | Accepted outcome |
|---|---|---|---|
| `vrs-scope-drift-*` | useful partial delivery and an agent-only boundary | the prompt supplied the conflict/escalation path; several gates scored document and decision-request compliance | 7/7 versus 7/7 |
| `vrs-scope-pressure-*` | retry behavior and refusal of unsafe local delivery | the prompt stated the refusal path; gates required exact escalation/governance surfaces | 6/6 versus 6/6 |
| `vrs-cross-file-*` | ordinary cross-file consistency | task and treatment repeated the same exact file/value checklist | 6/6 versus 6/6 |
| `vrs-definition-of-done-*` | packaging and completion | task enumerated the same seven deliverables as the treatment | 7/7 versus 7/7 |

The earlier results remain in
[`vrs-variations-results-20260728.md`](vrs-variations-results-20260728.md).
The cell directories are removed from the active corpus in ordinary Git
history and listed as superseded exclusions; the evidence is not rewritten.

## Designed-to-pass demonstration

`vrs-command-policy-demo` is a multi-file synthetic Orbit launcher repository.
The broad task asks for workspace sandbox policy enforcement in generated and
hand-authored task declarations. It does not state how shell data, policy data,
task scope, or workspace identity must be interpreted.

The supplied requirements and living specification contribute the material
architectural constraint: validation follows the actual decoded first-command
argv, parses one structured policy flag, compares opaque workspace bytes, and
excludes inactive, helper, non-Orbit, and workspaceless declarations. Raw
substring matching, path normalization, command execution, and machine-account
lookup are invalid solutions.

Eight held-out executable gates cover hostile-byte generation, accepted and
rejected policy forms, command boundaries, unaffected task classes, runnable
evidence, independent validator/generator mutations, coupling, and committed
repository isolation. No gate scores citations, requirement IDs, or prose.

## Matched catalog-activation A/B

`vrs-catalog-activation-present` and
`vrs-catalog-activation-absent` use the same Harbor reconciler task, Claude
Sonnet 5 medium seat, timeout, ordinary fixture, mutations, and blind judges.
Only two protected architecture documents differ.

The treatment specifies a host-local activation subject, durable
last-complete state, atomic receipt replacement, independent per-host version
skew, neutral peer absence without an explicit dependency, and replacement
controller adoption. The design generalizes the boundary and partition
problems from st2 PRs 73 and 74 into different names, formats, and APIs so a
memorized patch cannot satisfy it.

Eight identical executable gates measure durable activation, preservation on
missing/partial/invalid/older input, independent host progress, reachability
semantics, crash atomicity, service identity adoption, absence of global/remote
coupling, and three-seam mutation-valid testing.

The primary preregistered outcome is the executable gate vector and all-gates
verdict. Evidence supports VRS usefulness only if the present condition
outperforms the absent condition on architectural gates. Documentation
citations and prose are not outcome measures. The exact matched surfaces and
treatment hashes are frozen in
[`vrs-complex-preflight-20260730.tsv`](vrs-complex-preflight-20260730.tsv).
