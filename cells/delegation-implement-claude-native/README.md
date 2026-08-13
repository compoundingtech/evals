# delegation-implement-claude-native

One cell of the **delegation-parity tournament**: on real delegation work, are st2-managed sub-agents worse
than harness-native ones? The question, the matched arms, the metrics, the preregistered pass criterion, and
the limitations live in
[`evidence/delegation-parity-design-20260812.md`](../../evidence/delegation-parity-design-20260812.md).

| | |
| --- | --- |
| task | A small, well-scoped implementation: collision-safe slugs plus a mutation-valid regression test, delivered by a delegate rather than the coordinator. |
| arm | Harness-native delegation: one Claude seat fans the slices out to its own `Agent` sub-agents; there are no peer seats on the bus. |
| harness | Claude, 1 bus seat, one implementation slice |
| held-out judges | 6 gating + one non-gating `observations` signal judge |

**Matched with the other three arms of `delegation-implement-*`** byte for byte: the same `task.md`, the same
`judges/grade.sh`, the same frozen `fixture/repo`, the same deliverable contract, and the same
`max-timeout`. Only the delegation layer — the persona and which seats exist — differs. The outcome oracle
therefore cannot favour an arm: `grade.sh` receives the arm name only for the delegation-evidence judge.

The deliverables land in `findings/` at the catalog root and are attributed per delegate, so the same
mechanical grader reads a bus delegation and a native fan-out identically.

Run it (paid, one seat per declared agent):

```sh
st2 eval ./cells/delegation-implement-claude-native/
```

Prove the matching and the graders for free, without starting a model:

```sh
bin/check-delegation-parity.sh
```
