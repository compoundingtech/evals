# agent-spec-field-change-matrix

Contract-first, model-free acceptance matrix for the field-change rules in merged
[`compoundingtech/st2#102`](https://github.com/compoundingtech/st2/pull/102) at exact merge
[`e54a04a3ee8af6fe0b0bce4cd961f8188ac90525`](https://github.com/compoundingtech/st2/commit/e54a04a3ee8af6fe0b0bce4cd961f8188ac90525).

The cell is intentionally product-red. PR #102 changes documentation, not runtime behavior, and names eight
implementation gaps. A red case is accepted by the classification judges only when its public-CLI observation
matches the exact frozen map below; it is never counted as a conformance pass. The run step remains red until
all contract cases pass and the manifest is deliberately advanced with matching product evidence.

**Capabilities required:** `st2,pty,jq,awk,grep,sed`. No model and no provider. Every catalog, workspace, exec state,
message, PTY root, process, and receipt is created below the eval-owned temporary root.

## Closed-set map

| Outcome | Cases | Field / gap |
| --- | --- | --- |
| Existing pass | `invalid-type-refuses`, `role-metadata-adopts`, `compact-lowering-equal`, `provider-fields-core-noop` | F04, F05, F14, F15 |
| Expected red | `source-noop-heals` | F01 / G01 |
| Expected red | `workspace-survivor-event`, `resource-survivor-event`, `render-survivor-event` | F06-F08 / G02, G04, G06 |
| Expected red | `identity-remove-add`, `task-set-remove`, `task-id-change`, `spawn-drift-visible`, `invalid-policy-refuses`, `retire-removed-child` | F02, F09-F13 / G03, G04 |
| Expected red | `host-projection` | F03 / G05 |
| Expected red | `invalid-agent-isolated`, `plan-dry-run-order` | F16, shared R05 / G01, G07 |
| Expected red | `moved-intent-refusal` | unsupported moved intent / G08 |

The probes use only public `st2 validate`, `agents`, `up --once`, message, and task observation surfaces plus
isolated exec and PTY state. They do not import st2 source modules or treat unit tests as conformance evidence.

## Gates

- `judges/self-test.sh` plants missing-field, unknown-gap, expected-red-as-pass, result-drift, and residue
  mutations against the static oracle.
- The focused eval runs all public-behavior probes, prints one receipt row per closed-set case, cleans every
  exact eval-owned process/session, and exits nonzero while any contract case is red.
- `bin/check-corpus.sh` remains the model-free repository preflight and does not execute the product-red cell.

Run the static oracle and the expected-red product matrix with:

```sh
bash ./cells/agent-spec-field-change-matrix/judges/self-test.sh
st2 eval ./cells/agent-spec-field-change-matrix/ --keep
```

At the `e54a04a3` product pin the honest focused verdict is expected to contain five green classification
judges and one red run-step gate. Any different pass/red map is an unexpected product change and fails the
classification judge rather than silently changing the contract.
