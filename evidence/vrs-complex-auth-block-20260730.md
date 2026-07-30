# Complex VRS provider block — 2026-07-30

This record preserves the operational result of the first authorized complex
VRS provider attempt. It is not VRS outcome evidence.

## Exact attempted scope

- Source: `a301be9cd2b3c20b0788e665fee894df98353784`
- Runner: st2 source `9887b28`
- Queue: `vrs-command-policy-demo`,
  `vrs-catalog-activation-absent`, then
  `vrs-catalog-activation-present`
- Durable state: `.eval-runs/vrs-complex-20260730`

The complete model-free preflight passed before the first seat. The isolated
Claude seat then reported HTTP 401 because its OAuth access token had expired
and requested interactive re-authentication. The contemporaneous
`claude auth status --json` metadata still reported a logged-in first-party
Claude subscription. Therefore that metadata is not a freshness proof.

The run was stopped before any judge, second cell, or accepted model output.
The failure envelope is
`.eval-runs/vrs-complex-20260730/failures/vrs-command-policy-demo.20260730T081430Z.env`;
it records exit 143, no timeout, and no usage banner. There is no successful
provider receipt, no score, no trustworthy usage/cost total, and no VRS
present/absent comparison to report.

## Cleanup observation

After the runner stopped, the isolated catalog's normal `down` path classified
the ad-hoc seat under `other-host (1): package` and left the seat PTY, Claude,
and DING processes running. An explicit isolated-catalog PTY kill removed that
residue. Process checks then found no remaining eval seat or catalog process.
The production st2 service and protected agent were not restarted or modified.

This is separate teardown evidence: a package-host-classified ad-hoc PTY is not
fully removed by the current isolated `down` path. It is not a defect in the
three VRS cells and is not treated as provider or VRS evidence.

## Fail-closed correction

Claude-selected paid queues now require a sanitized receipt from one exact
bounded real-provider turn. The receipt gate rejects metadata-only state,
receipts older than ten minutes, source/CLI/state-context drift, a non-exact
response, unknown or duplicate fields, and cost above the USD 0.05 probe
ceiling. Secret values are neither printed nor hashed.

Interactive OAuth refresh and the real proof remain human-authorized actions.
No provider retry is permitted until the owner confirms refreshed credentials
and approves the bounded probe.
