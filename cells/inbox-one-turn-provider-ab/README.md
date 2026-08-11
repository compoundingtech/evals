# inbox-one-turn-provider-ab

Focused real-provider A/B scaffold for [st2 #238](https://github.com/compoundingtech/st2/issues/238). The
same mixed Claude/Codex cell is run at two exact immutable st2 heads:

| Arm | Delivery | Expected inference/tool shape |
|---|---|---|
| baseline | ordered bounded metadata without bodies | discovery tool call, another inference, then action |
| candidate | the same ordered slice with bounded bodies | one inference can issue one shell tool call containing the existing reply/archive commands |

There is deliberately no `settle`, claim, lease, cursor, provider opt-in, or eval-only delivery switch. The
candidate's read-only `st2 message delivery` seam renders the existing
`st2 message ls <identity> --json --include-body` result into the maintained provider's delivery envelope.
The exact st2 binary is the only A/B variable. This makes the cell transplantable when provider adapters move
behind the driver boundary tracked by st2 #162.

## Scenario and evidence

Both maintained providers receive the same resettable synthetic sequence:

1. two cold-backlog messages;
2. a bounded three-message burst injected after the subject's first bus CLI process begins;
3. one post-batch message injected only after the first five messages are durably archived.

The held-out outcome judge requires an exact threaded acknowledgement and one archive copy for all six
tokens, an empty subject inbox, and subsequent delivery and handling of the final post-batch arrival. The
measurement judge emits JSON containing every wrapped bus CLI argv, provider-delivery/discovery/mutation
counts, first subject inbox-operation classification,
source payload bytes, first/last CLI timestamps, scenario timestamps, exact archive filenames, `st2
--version`, and the runner binary SHA256. The wrapper forwards to the real installed `st2`; it does not model
delivery or settlement.

Provider/API call counts, provider-reported input/output/cache tokens, tool-call boundaries, total prompt
bytes, wall time, exact evals source commit, and exact st2 source commit belong in the normal tracked run
receipt and append-only `evidence/run-history.tsv` row. CLI process counts are a robust fixture-local metric.
The Claude hook's read-only `message delivery` process is reported separately and is not mislabeled as a
model tool call. The candidate is accepted only when the provider transcript
also proves one inference before one shell action call; a green archive outcome alone is insufficient.

Codex uses a canonical Agent Spec with structured `argv` plus `deliver "app-server"`, so both arms exercise
the native #237 app-server seam rather than generic PTY DING. Canonical Agent Specs also keep the A/B on the
driver-facing declaration boundary: both exact heads consume the same cell even though the baseline compact
eval grammar cannot express structured argv. The setup uses st2's existing batch `pretrust` utility before
boot, matching the standard compact-eval lifecycle without adding a provider-specific trust mechanism.
The immutable baseline is st2 #237 head
`1d06c4b263a7c5a2a6b8eec1f2e8c4fbea5e2edc`; the candidate is st2 #239 head
`c1a0f90dd4814ec3ce8067219530d7bd8723e191`. Claude keeps native
generic `ding`, plus the candidate `UserPromptSubmit` hook declaration. Its guarded command is a clean no-op
when the baseline hook target is absent, so metadata delivery falls through to one `ls --include-body` without
adding a hook error; at the candidate head it injects the bounded bodies into the same prompt inference.

Exact Nix-built runner binaries used for the pending matched run:

| arm | st2 version | binary SHA256 |
|---|---|---|
| baseline | `st2 0.1.0+1d06c4b` | `06997b2c63ddf58678c7a4d024de62d957faf6c2bdc56766c15501e7946c1338` |
| candidate | `st2 0.1.0+c1a0f90` | `6795c8539ca308fc49b439a3b6495d2bcd2ad4a5ede4cfe02dd53be2f2c67d81` |

No provider/model result is claimed until both exact arms complete and their transcripts are graded.

## Scope boundary

This is related to evals #57, but does not duplicate its broader PTY matrix. It excludes idle/activity
classification, partial human drafts, input collision, DND, compaction/crash routing, guarded writes, and
generic/custom adapters. Those are transport-safety axes, not #238's body-availability efficiency axis.

Free fixture/grader self-test and corpus gate:

```sh
bash cells/inbox-one-turn-provider-ab/fixture/self-test.sh
bin/generate-catalog.sh --write
bin/check-corpus.sh
```

An eventual paid run requires explicit approval and exact baseline/candidate st2 binary provenance. Do not
run either arm merely because the cell exists.
