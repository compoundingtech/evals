# agent-spec-field-change-matrix

Contract-first, model-free acceptance matrix for the field-change rules in merged
[`compoundingtech/st2#102`](https://github.com/compoundingtech/st2/pull/102) at exact merge
[`e54a04a3ee8af6fe0b0bce4cd961f8188ac90525`](https://github.com/compoundingtech/st2/commit/e54a04a3ee8af6fe0b0bce4cd961f8188ac90525).

This eval is expected to fail until st2 implements the documented field-change rules. PR #102 changes
documentation, not runtime behavior, and names eight implementation gaps. The classification judges accept a
known failure only when its public CLI result matches the exact map below. They never count a known failure as
a conformance pass. The run step continues to fail until all contract cases pass and matching product evidence
updates the manifest.

**Capabilities required:** `st2,pty,jq,awk,grep,sed,coreutils`. No model and no provider. Every catalog, workspace, exec state,
message, PTY root, process, and receipt is created below the eval-owned temporary root.

## Closed-set map

| Outcome | Cases | Field / gap |
| --- | --- | --- |
| Existing pass | `source-noop-heals`, `compact-lowering-equal`, `provider-fields-core-noop`, `invalid-agent-isolated` | F01, F14-F16 |
| Expected red | `invalid-type-refuses` | F04 / G01 |
| Expected red | `workspace-survivor-event`, `resource-survivor-event`, `render-survivor-event` | F06-F08 / G02, G04, G06 |
| Expected red | `identity-remove-add`, `task-set-remove`, `task-id-change`, `spawn-drift-visible`, `invalid-policy-refuses`, `retire-removed-child` | F02, F09-F13 / G03, G04 |
| Expected red | `host-projection` | F03 / G05 |
| Expected red | `role-metadata-adopts`, `plan-dry-run-order` | F05, shared R05 / G07 |
| Expected red | `moved-intent-refusal` | unsupported moved intent / G08 |

The probes use only public `st2 validate`, `ls`, `agents`, `tasks`, `up --once`, message, and task observation
surfaces plus isolated exec, process-generation, and PTY state. The F14 arms compare compact argv lowering with
an explicit PTY and send a real inbox message through both native DING sidecars; the F06-F08 oracle requires one durable stable-ID event with class,
affected paths or Resource descriptors, post-commit visibility, coalescing, replay idempotence, unchanged
silence, and no file or secret bytes. The probes do not import st2 source modules or treat unit tests as
conformance evidence.

## Gates

- `judges/self-test.sh` plants missing-field, unknown-gap, expected-red-as-pass, stale-map-with-equal-counts,
  result-drift, and residue mutations against the static oracle.
- The focused eval runs all public-behavior probes, prints one receipt row per closed-set case, cleans every
  exact eval-owned process/session, and exits nonzero while any contract case is red.
- `bin/check-corpus.sh` remains the model-free repository preflight and does not execute this expected-failure
  cell.

Run the static oracle and the expected-failure product matrix with:

```sh
bash ./cells/agent-spec-field-change-matrix/judges/self-test.sh
st2 eval ./cells/agent-spec-field-change-matrix/ --keep
```

At the `e54a04a3` product pin the honest focused verdict is expected to contain five green classification
judges and one red run-step gate. Any different pass/red map is an unexpected product change and fails the
classification judge rather than silently changing the contract.
