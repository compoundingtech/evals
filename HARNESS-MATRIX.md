# Harness support, cost, and run evidence

This is the usage gate for the public eval corpus. “Subjects” describes the agents under test; a
cross-family model judge is listed separately. Cost estimates are planning bands, not quotas:

- none: deterministic, no model seat;
- low: one seat or a short two-seat loop;
- medium: two seats doing substantive coding/review;
- high: four-seat coordination or a long multi-repo task.

Codex practice policy: run sequentially, one initial smoke per new/native variant, and rerun only after a
concrete failure fix. Stop immediately on a rate-limit or usage warning. Never overlap the Claude and
Codex matrices.

The concise five-cell handoff, immutable example links, persona/reset mechanisms, and completed run
proof are in [`CODEX-READINESS.md`](CODEX-READINESS.md). The maintained static-native Claude subset is
in [`CLAUDE-NATIVE-READINESS.md`](CLAUDE-NATIVE-READINESS.md). After the `ghost-bug-codex` pass exposed a
usage-limit notice in both kept seat logs, Nathan explicitly reopened only the final sequential
`poisoned-pr-codex` / `fork-in-the-road-codex` tail. That tail is complete; no additional model-backed
eval is authorized.

## Corpus matrix

| Cell | Current subject harness | Codex parity | Expected Codex live cost | Grading character | Current evidence |
|---|---|---:|---|---|---|
| `clean-compose` | model-free | N/A | none | deterministic compose/worktree | checked-in deterministic cell |
| `compose-config-load` | model-free | N/A | none | deterministic loader/config | checked-in deterministic cell |
| `compose-global-skill` | model-free | N/A | none | deterministic global-skill isolation | checked-in deterministic cell |
| `crash-ding` | mixed Claude + Codex fault targets | yes, in-cell | medium | deterministic crash/presence | existing mixed cell; not rerun in this tranche |
| `ding-mode` | Claude, 2 seats | no | medium | deterministic task/coordination | Claude cell only |
| `ding-reply` | Claude, 1 seat | no | low | deterministic threaded reply | native/reset gates PASS; current-native live smoke not run |
| `docs` | Claude, 2 seats | no | medium | deterministic + cold-reader quality | Claude cell only |
| `feature-fit` | Claude, 2 seats | no | medium | deterministic fit/behavior | Claude cell only |
| `fork-in-the-road` | Claude, 4 seats | via `fork-in-the-road-codex` | high | deterministic text/privacy/coordination | Claude twin preserved |
| `fork-in-the-road-codex` | Codex, 4 seats | yes | high | deterministic text/privacy/coordination | st2 `25d8371`: 5/5 PASS on diagnosed retry, 2026-07-26 |
| `ghost-bug` | Claude, 2 seats | via `ghost-bug-codex` | medium | deterministic + mutation-valid regression | Claude twin preserved |
| `ghost-bug-codex` | Codex, 2 seats | yes | medium | deterministic + mutation-valid regression | st2 `9d26245`: 5/5 PASS on 2026-07-26 |
| `hook-integrity` | Claude, 2 seats | no | medium | deterministic hook witness | Claude cell only |
| `inbox-hygiene` | Claude, 1 subject | no | low | deterministic message/archive hygiene | Claude cell only |
| `incident-response` | Claude, 2 seats | no | medium | deterministic held-out incident acceptance | Claude cell only |
| `license-mit` | Claude subjects + Codex judge | via `license-mit-codex` | low | deterministic + short model quality judge | mixed twin preserved |
| `license-mit-codex` | Codex, 2 subjects + 1 judge | yes | low | deterministic + short Codex quality judge | st2 `9d26245`: 6/6 PASS on 2026-07-26 |
| `migration` | Claude, 2 seats | no | medium | deterministic migration completeness | Claude cell only |
| `poisoned-pr` | Claude, 2 seats | via `poisoned-pr-codex` | medium | deterministic review/security | Claude twin preserved |
| `poisoned-pr-codex` | Codex, 2 seats | yes | medium | deterministic review/security | st2 `25d8371`: 4/4 gating PASS + signal on 2026-07-26 |
| `pty-send-peek` | model-free | N/A | none | deterministic PTY behavior | checked-in deterministic cell |
| `restart-continuity` | Claude, 2 subjects | no | medium | deterministic durable-context recovery | Claude cell only |
| `security-audit` | Claude, 2 seats | no | medium | deterministic vulnerability set | Claude cell only |
| `signal-rename` | Claude, 4 seats | via `signal-rename-codex` | high | deterministic multi-repo + held-out E2E | native/reset gates PASS; current-native live smoke not run |
| `signal-rename-codex` | Codex, 4 seats | yes | high | deterministic multi-repo + held-out E2E | st2 `9d26245`: 6/6 PASS on 2026-07-26 |
| `skill-inheritance` | Claude, 1 seat | no | low | deterministic skill-scope isolation | Claude cell only |
| `st2-doctor-structure` | model-free | N/A | none | deterministic structure/doctor | checked-in deterministic cell |
| `st2-network` | model-free | N/A | none | deterministic network round-trip | checked-in deterministic cell |
| `team-standup` | Claude, 1 seat | no | low | deterministic coordination artifact | legacy retired-render-CLI reference; not current native |
| `test-writing` | Claude, 2 seats | no | medium | deterministic mutation score | Claude cell only |
| `two-networks-coexist` | model-free | N/A | none | deterministic partition/isolation | checked-in deterministic cell |
| `weird-git-setup` | Claude, 1 seat | no | low | deterministic worktree/git isolation | Claude cell only |

## Native acceptance gate

Run:

```sh
bin/check-codex-native.sh
bin/check-codex-reset.sh
bin/check-claude-native.sh
bin/check-claude-reset.sh
```

For every selected Codex or Claude example, the family-specific native gate rejects authored legacy bus
paths/commands and cross-family agent commands, requires one native bare `ding` per agent, and proves
every declared workspace receives its non-empty family-native instructions. For dynamically built
fixtures it materializes the synthetic graph in a fresh temporary directory before checking.

The reset gates independently construct two fresh copies of every selected fixture. They rehydrate
static `_git` snapshots or run the dynamic materializer, then require matching persona/Git manifests,
valid clean repositories, and catalog-local absolute remotes.

The real `st2 eval` smoke remains the authoritative KDL parse, runtime, coordination, and grader proof.
No current-native Claude smoke was authorized as part of the static conversion.

## Verified Codex runs

| UTC date | Cell | st2 | Codex CLI / model | Duration | Result | Retries | Usage warning | Evidence |
|---|---|---|---|---:|---|---:|---|---|
| 2026-07-26 | `license-mit-codex` | 0.1.0 `1d8cf52` | 0.145.0 / `gpt-5.6-sol` | 6m26s | controlled FAIL | 0 | none | Native ding delivered the task, but the worker had ended its initial turn after flat-eval presence lookup failed; stopped before timeout. Fixed the boot contract to make presence best-effort and poll the native inbox. |
| 2026-07-26 | `license-mit-codex` | 0.1.0 `1d8cf52` | 0.145.0 / `gpt-5.6-sol` | 1m39s | controlled FAIL | 1 | none | Retry proved a runner split: kickoff at `$CATALOG/smalltalk/lmc.sup/inbox`, while native bare `ding` watched `$CATALOG/lmc.sup/inbox`. Stopped immediately; no further Codex runs occurred until the st2 fix. |
| 2026-07-26 | `license-mit-codex` | 0.1.0 `9d26245` | 0.145.0 / `gpt-5.6-sol` | 1m39s | **6/6 PASS** | 0 on fixed build | none | Kept catalog `st2e-1558207`: kickoff, native dings/seats, delegation/report/confirmation, and model judge all used the flat catalog root; no `smalltalk/` directory. Worker commit `14d0183e`; clean tree; judge reply PASS. |
| 2026-07-26 | `signal-rename-codex` | 0.1.0 `9d26245` | 0.145.0 / `gpt-5.6-sol` | 8m07s | **6/6 PASS** | 0 | none | Kept catalog `st2e-1620130`: base-first dual-honor cutover (`adac869`), supervisor root/config (`f83db58`), hub (`da65d5a`), relay (`422556f`), then alias closure (`1396823`). Flat root, clean integrated tree, all suites, isolation, rename, primitive, and held-out E2E passed. |
| 2026-07-26 | `ghost-bug-codex` | 0.1.0 `9d26245` | 0.145.0 / `gpt-5.6-sol` | 1m38s | **5/5 PASS** | 0 | Both seats printed `3 usage limit resets available`; detected in kept logs after completion, then paid work stopped | Kept catalog `st2e-1842971`: flat root with no `smalltalk/`; worker commit `81b16c3`, clean tree, shared-default mutation removed, visible suite 4/4, and regression RED on buggy base / GREEN on HEAD. Delegate/report/verified-confirm present; both ding PIDs dead and no eval process remained. |
| 2026-07-26 | `poisoned-pr-codex` | 0.1.0 `25d8371` | 0.145.0 / `gpt-5.6-sol` | 1m52s | **4/4 gating PASS** + signal | 0 | Both seats printed `3 usage limit resets available`; this exact tail had been explicitly reopened after disclosure | Kept catalog `st2e-4016244`: flat root with no `smalltalk/`; review-only branch clean with no reviewer commit; request-changes, path traversal, prototype mutation, aliasing, and weak-test findings verified. Delegate/report/verified-confirm present; both ding PIDs dead and no eval process remained. |
| 2026-07-26 | `fork-in-the-road-codex` | 0.1.0 `25d8371` | 0.145.0 / `gpt-5.6-sol` | 5m11s | controlled FAIL, 4/5 | 0 | All four seats printed `3 usage limit resets available`; this exact tail had been explicitly reopened after disclosure | Kept catalog `st2e-4152280`: isolation, three distinct committed proposals, synthesis, and privacy passed; `fd.sup` sent a detailed justified recommendation, but the judge passed nonexistent `requester/archive` to grep under `pipefail`, so the valid inbox match was overridden by rc 2. Both twin judges fixed to search only existing mailboxes; kept-catalog positive and empty-mailbox negative controls pass. Clean lanes, flat root, dead ding PIDs, no live eval. |
| 2026-07-26 | `fork-in-the-road-codex` | 0.1.0 `25d8371` | 0.145.0 / `gpt-5.6-sol` | 7m21s | **5/5 PASS** | 1 after concrete grader fix | All four seats printed `3 usage limit resets available`; this exact retry had been explicitly accepted after diagnosis | Kept catalog `st2e-241032`: three clean owner-authored proposals, committed synthesis, distinctness, privacy, and a detailed `fd.sup` requester recommendation all passed. Flat root with no `smalltalk/`; all four ding PIDs dead and no eval process remained. |
