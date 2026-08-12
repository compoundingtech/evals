# delegation-review-codex-native

One cell of the **delegation-parity tournament**: on real delegation work, are st2-managed sub-agents worse
than harness-native ones? The question, the matched arms, the metrics, the preregistered pass criterion, and
the limitations live in
[`evidence/delegation-parity-design-20260812.md`](../../evidence/delegation-parity-design-20260812.md).

| | |
| --- | --- |
| task | Parallel independent review of a proposed patch whose suite is green: three real defects hide among two behaviour-preserving hunks that look suspicious. |
| arm | Harness-native delegation: one Codex seat fans the slices out to its own `spawn_agent` sub-agents; there are no peer seats on the bus. |
| harness | Codex, 1 bus seat, two independent review slices |
| held-out judges | 4 gating + one non-gating `observations` signal judge |

**Matched with the other three arms of `delegation-review-*`** byte for byte: the same `task.md`, the same
`judges/grade.sh`, the same frozen `fixture/repo`, the same deliverable contract, and the same
`max-timeout`. Only the delegation layer — the persona and which seats exist — differs. The outcome oracle
therefore cannot favour an arm: `grade.sh` receives the arm name only for the delegation-evidence judge.

The deliverables land in `findings/` at the catalog root and are attributed per delegate, so the same
mechanical grader reads a bus delegation and a native fan-out identically.

Run it (paid, one seat per declared agent):

```sh
st2 eval ./cells/delegation-review-codex-native/
```

Prove the matching and the graders for free, without starting a model:

```sh
bin/check-delegation-parity.sh
```
