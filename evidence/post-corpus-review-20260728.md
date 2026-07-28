# Post-corpus review — exact st2 `9887b28`

Date: 2026-07-28
Final corpus commit: `a49fb0ffa00c525e361b3178fb7c35b93538501f`
Runtime disposition: clean; production `st2.service` inactive; the protected eval runtime was untouched.

## Executive result

The accepted 30-cell evidence set finished **28 PASS / 2 model FAIL**. The two preserved failures are
`license-mit` (5/6) and `weird-git-setup` (5/6). Neither was an auth, quota, st2 runtime, messaging, or cleanup
failure.

During the run, four corpus/substrate issues were found and repaired before model-free regrade:

1. VRS-Present's one-line literal-copy judge rejected a valid multiline spec.
2. VRS-Absent's escalation judge leaked Present-only treatment identifiers and initially rejected a natural
   conflict heading.
3. `st2-doctor-structure` asserted obsolete supervisor wording instead of the exact task-health contract.
4. `pty-send-peek` relied on `st2 down` to remove an ad-hoc PTY; the cell now explicitly kills its owned ad-hoc
   session and asserts zero running residue.

Those repairs passed full free preflight and final regrades. They are not counted as model failures.

## Preserved model failures

### 1. `license-mit` — keep as a valid failure; schedule one confirmation rerun

Durable run artifacts: failure receipt `license-mit.20260728T132453Z.env` and matching run log; matched-control
receipt `license-mit-codex.env` and matching run log.

**Evidence.** The exact prompt says the widget library “should be MIT” and is currently proprietary. The
fixture exposes proprietary state in both `LICENSE` and `package.json` (`LicenseRef-Proprietary`). The Claude
supervisor narrowed its delegation to replacing `LICENSE`; the worker changed and committed only `LICENSE`;
the supervisor verified only that file. The result passed isolation, coordination, canonical license text,
clean commit, and the independent confirmation judge, but failed the declarative package metadata judge:

`package.json.license` remained `LicenseRef-Proprietary`.

**Matched control.** `license-mit-codex` used the same task, fixture, and six judges. Its worker changed both
`LICENSE` and `package.json`, its supervisor verified both, and it passed 6/6.

**Disposition.** **KEEP** the prompt, fixture, and judge. This is a meaningful end-to-end completeness failure:
the repository still advertised a proprietary license to tooling. Do not weaken the judge. Run one bounded
confirmation replication later to distinguish a stable family difference from one stochastic miss; preserve
the current 5/6 as the primary observation regardless of the rerun.

### 2. `weird-git-setup` — fix the secondary requirement, then rerun once

Durable run artifacts: failure receipt `weird-git-setup.20260728T154731Z.env` and matching run log. There is no
family-matched control.

**Evidence.** The worker correctly resolved a linked worktree, committed on `feature`, fixed the root cause,
kept the sibling/main worktrees clean, and passed the suite. It changed only `src/clamp.js`. It did not add a
test and explicitly treated the seed's existing failing test as “the regression test you flagged”; the
committed test count remained three, so the literal add-a-test judge correctly failed.

**Control quality.** There is no family-matched Weird-Git control. More importantly, the seed already contains
the exact asserted regression:

`clamp(15, 0, 10) === 10`

The prompt then asks for another test “that would catch this exact bug.” That is explicit but redundant. The
cell's advertised discriminator is linked-worktree discovery and branch-local commit behavior, which the model
passed. The failed secondary gate therefore dominates the headline with an unnatural duplicate-test demand.

**Disposition.** **FIX, then RERUN once.** Preserve the current 5/6 evidence, but do not use it as a clean
worktree-capability failure. Preferred fix: remove the redundant “add” requirement/gate and require preserving
the already-red regression, since mutation-quality test writing is covered directly by `test-writing`.
Alternative: explicitly request a *second distinct above-range case* and name why redundancy is desired.
Do not rerun until one of those contracts is chosen and the planted negative is updated.

## Complete 30-cell outcomes

| Cell | Outcome | Final score |
|---|---:|---:|
| crash-ding | PASS | 5/5 |
| ding-mode | PASS | 4/4 |
| ding-reply | PASS | 2/2 |
| docs | PASS | 5/5 |
| feature-fit | PASS | 5/5 |
| fork-in-the-road | PASS | 5/5 |
| fork-in-the-road-codex | PASS | 5/5 |
| ghost-bug | PASS | 5/5 |
| ghost-bug-codex | PASS | 5/5 |
| hook-integrity | PASS | 10/10 |
| inbox-hygiene | PASS | 4/4 |
| incident-response | PASS | 5/5 |
| license-mit | **FAIL** | **5/6** |
| license-mit-codex | PASS | 6/6 |
| migration | PASS | 5/5 |
| poisoned-pr | PASS | 4/4 |
| poisoned-pr-codex | PASS | 4/4 |
| pty-send-peek | PASS | 10/10 |
| restart-continuity | PASS | 5/5 |
| security-audit | PASS | 3/3 |
| signal-rename | PASS | 6/6 |
| signal-rename-codex | PASS | 6/6 |
| skill-inheritance | PASS | 3/3 |
| st2-doctor-structure | PASS | 5/5 |
| st2-network | PASS | 4/4 |
| test-writing | PASS | 3/3 |
| two-networks-coexist | PASS | 17/17 |
| vrs-scope-drift-absent | PASS | 7/7 model-free corrected regrade |
| vrs-scope-drift-present | PASS | 7/7 model-free corrected regrade |
| weird-git-setup | **FAIL** | **5/6** |

## Visible usage

Accepted 30-cell evidence:

- Claude: 40 declared seats, 1,054 deduplicated calls, 3,364 input, 4,799,252 cache-create,
  83,989,670 cache-read, 509,690 output tokens; **$61.647855 API-equivalent**.
- Codex: 17 declared seats, 12,690,369 input, 11,815,168 cached input, 101,864 output,
  19,419 reasoning-output, **12,792,233 total tokens**.

An earlier invalid pre-release License-MIT canary on source `8280069` exited 143 before judgment and is excluded
from accepted evidence. Including its visible persisted usage raises totals to:

- Claude: 42 seat launches, 1,066 calls, 3,396 input, 4,825,658 cache-create, 84,616,723 cache-read,
  512,240 output; **$62.0327529 API-equivalent**.
- Codex: 18 seat launches, 12,784,210 input, 11,893,760 cached input, 102,519 output,
  19,688 reasoning-output, **12,886,729 total tokens**.

The companion JSON contains the accounting caveats and exact fields.

## Missing evals, grounded in `AGENT-SPEC.md`

Priority order:

1. **Presence/DING state matrix (model-free).** Prove busy/away delivery, fresh-DND suppression, abandoned-DND
   aging to derived unknown, delivery resumption, FIFO order, and failed-send queue-head retention. Existing
   DING cells cover normal wake, reply, crash notification, and redelivery, but not the specified state matrix.
2. **Reconcile/retire/keep lifecycle matrix (model-free).** Exercise adopt-live, launch-missing, collect/restart
   dead non-keep, freeze dead keep, retired-live stop even with keep, and retired-dead final collection.
   Restart-Continuity evaluates agent work continuity, not the catalog lifecycle state machine.
3. **Render safety matrix (model-free).** Cover `copy`, `file`, `json-upsert`, `ensure-line`, and `git-exclude`;
   assert byte-identical tracked writes pass, real tracked changes fail closed, unsafe destinations fail, and
   one agent's materialization failure does not suppress another. Hook-Integrity covers installed hooks, not
   the complete render contract.
4. **Strict validation/JSON diagnostics (model-free).** Plant duplicate ids, nameless tasks, missing copy
   sources, unsafe/missing paths, dangling imports, absent supervisors, and verify stable issue metadata plus
   warning-to-error conversion under `--strict`.
5. **Exec-task lifecycle/logging (model-free).** Verify no PTY allocation, detached process group, transient
   scope where available, bounded previous-log generation, and teardown/adoption behavior.
6. **Context/resource restart continuity (small model-backed or deterministic helper).** Prove `context
   write/append/read` and resource references survive restart without relying on Git as the durable substrate.
7. **Host-lock health negatives (model-free).** Extend Doctor coverage to explicit-supervisor-required,
   stale-lock, foreign-live-owner, and bounded unreadable-PTY-runtime cases.

## Remove or consolidate candidates

1. **Consolidate family mirrors that produced identical outcomes.** `ghost-bug*`, `poisoned-pr*`, and
   `fork-in-the-road*` all passed in both families. Keep one canonical cell per scenario in every run and
   rotate the alternate family on a scheduled matrix run. This retains cross-family detection while reducing
   routine paid seats.
2. **Run one Signal-Rename family per routine cycle.** Both four-seat mirrors passed the same six gates. Keep
   both definitions, but alternate families; reserve the full pair for release qualification.
3. **Keep the License-MIT pair for now.** It is the only matched family pair that produced a substantive
   divergent result, so consolidation would discard high-value evidence.
4. **Consolidate Weird-Git's redundant test-quality gate into `test-writing`.** Keep the linked-worktree cell;
   remove or explicitly redefine only the duplicate-test requirement.
5. **Keep the cheap model-free substrate cells.** `st2-network`, `pty-send-peek`, Doctor, Hook-Integrity, and
   Two-Networks found real contract/cleanup defects during this run; their overlap is complementary and cheap.

## Recommended next action

Do not change or rerun either failed cell as part of this review. Accept License-MIT as a valid failure and
queue one future replication. Open a corpus change for Weird-Git to align the regression-test requirement with
its linked-worktree headline, add a planted negative for the chosen contract, run full free preflight, and only
then authorize one paid rerun.
