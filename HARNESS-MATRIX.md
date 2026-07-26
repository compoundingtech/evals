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

## Corpus matrix

| Cell | Current subject harness | Codex parity | Expected Codex live cost | Grading character | Current evidence |
|---|---|---:|---|---|---|
| `clean-compose` | model-free | N/A | none | deterministic compose/worktree | checked-in deterministic cell |
| `compose-config-load` | model-free | N/A | none | deterministic loader/config | checked-in deterministic cell |
| `compose-global-skill` | model-free | N/A | none | deterministic global-skill isolation | checked-in deterministic cell |
| `crash-ding` | mixed Claude + Codex fault targets | yes, in-cell | medium | deterministic crash/presence | existing mixed cell; not rerun in this tranche |
| `ding-mode` | Claude, 2 seats | no | medium | deterministic task/coordination | Claude cell only |
| `ding-reply` | Claude, 1 seat | no | low | deterministic threaded reply | Claude cell only |
| `docs` | Claude, 2 seats | no | medium | deterministic + cold-reader quality | Claude cell only |
| `feature-fit` | Claude, 2 seats | no | medium | deterministic fit/behavior | Claude cell only |
| `fork-in-the-road` | Claude, 4 seats | via `fork-in-the-road-codex` | high | deterministic text/privacy/coordination | Claude twin preserved |
| `fork-in-the-road-codex` | Codex, 4 seats | yes | high | deterministic text/privacy/coordination | native source gate PASS; live smoke blocked by st2 `1d8cf52` bus-root mismatch |
| `ghost-bug` | Claude, 2 seats | via `ghost-bug-codex` | medium | deterministic + mutation-valid regression | Claude twin preserved |
| `ghost-bug-codex` | Codex, 2 seats | yes | medium | deterministic + mutation-valid regression | native source gate PASS; live smoke blocked by st2 `1d8cf52` bus-root mismatch |
| `hook-integrity` | Claude, 2 seats | no | medium | deterministic hook witness | Claude cell only |
| `inbox-hygiene` | Claude, 1 subject | no | low | deterministic message/archive hygiene | Claude cell only |
| `incident-response` | Claude, 2 seats | no | medium | deterministic held-out incident acceptance | Claude cell only |
| `license-mit` | Claude subjects + Codex judge | via `license-mit-codex` | low | deterministic + short model quality judge | mixed twin preserved |
| `license-mit-codex` | Codex, 2 subjects + 1 judge | yes | low | deterministic + short Codex quality judge | native source gate PASS; live run blocked by st2 `1d8cf52` eval bus-root mismatch |
| `migration` | Claude, 2 seats | no | medium | deterministic migration completeness | Claude cell only |
| `poisoned-pr` | Claude, 2 seats | via `poisoned-pr-codex` | medium | deterministic review/security | Claude twin preserved |
| `poisoned-pr-codex` | Codex, 2 seats | yes | medium | deterministic review/security | native source gate PASS; live smoke blocked by st2 `1d8cf52` bus-root mismatch |
| `pty-send-peek` | model-free | N/A | none | deterministic PTY behavior | checked-in deterministic cell |
| `restart-continuity` | Claude, 2 subjects | no | medium | deterministic durable-context recovery | Claude cell only |
| `security-audit` | Claude, 2 seats | no | medium | deterministic vulnerability set | Claude cell only |
| `signal-rename` | Claude, 4 seats | via `signal-rename-codex` | high | deterministic multi-repo + held-out E2E | Claude twin preserved |
| `signal-rename-codex` | Codex, 4 seats | yes | high | deterministic multi-repo + held-out E2E | native source/materialization gate PASS; live smoke blocked by st2 `1d8cf52` bus-root mismatch |
| `skill-inheritance` | Claude, 1 seat | no | low | deterministic skill-scope isolation | Claude cell only |
| `st2-doctor-structure` | model-free | N/A | none | deterministic structure/doctor | checked-in deterministic cell |
| `st2-network` | model-free | N/A | none | deterministic network round-trip | checked-in deterministic cell |
| `team-standup` | Claude, 1 seat | no | low | deterministic coordination artifact | Claude cell only |
| `test-writing` | Claude, 2 seats | no | medium | deterministic mutation score | Claude cell only |
| `two-networks-coexist` | model-free | N/A | none | deterministic partition/isolation | checked-in deterministic cell |
| `weird-git-setup` | Claude, 1 seat | no | low | deterministic worktree/git isolation | Claude cell only |

## Native acceptance gate

Run:

```sh
bin/check-codex-native.sh
```

For every selected Codex twin the gate rejects authored legacy bus paths/commands and non-Codex agent
commands, requires one native bare `ding` per agent, and proves every declared workspace receives a
non-empty `AGENTS.md`. For dynamically built fixtures it materializes the synthetic graph in a fresh
temporary directory before checking.

The real `st2 eval` smoke remains the authoritative KDL parse, runtime, coordination, and grader proof.

## Verified Codex runs

| UTC date | Cell | st2 | Codex CLI / model | Duration | Result | Retries | Usage warning | Evidence |
|---|---|---|---|---:|---|---:|---|---|
| 2026-07-26 | `license-mit-codex` | 0.1.0 `1d8cf52` | 0.145.0 / `gpt-5.6-sol` | 6m26s | controlled FAIL | 0 | none | Native ding delivered the task, but the worker had ended its initial turn after flat-eval presence lookup failed; stopped before timeout. Fixed the boot contract to make presence best-effort and poll the native inbox. |
| 2026-07-26 | `license-mit-codex` | 0.1.0 `1d8cf52` | 0.145.0 / `gpt-5.6-sol` | 1m39s | controlled FAIL | 1 | none | Retry proved a runner split: kickoff at `$CATALOG/smalltalk/lmc.sup/inbox`, while native bare `ding` watched `$CATALOG/lmc.sup/inbox`. Stopped immediately; no further Codex runs pending an st2 fix. |
