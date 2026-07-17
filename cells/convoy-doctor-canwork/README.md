# convoy-doctor-canwork — convoy's own self-test proves the full autonomous org WORKS on this machine

**Discriminates:** does `convoy doctor --full` actually **prove** the full autonomous org works — a real
CoS→supervisor→worker that **delegated + shipped a graded fix, hands-off** — and **fail closed** on a broken setup?
(held-out; no LLM judge — grades doctor's real stdout + exit code)

**Capabilities required:** `claude,convoy,st,pty,git` · run `bin/st-evals preflight`. The preflight-fails-closed floor
is box-free; the can-work headline rides the box (heavy, gated).

## What it proves (the README promise — "and can do real work")

`convoy doctor --full` is convoy's built-in end-to-end self-test: it spawns a real CoS→sup→worker org and grades
that they delegated + shipped a **graded fix** hands-off. This cell is the **dedicated gate** for that headline —
kept **separate** from [`convoy-doctor-structure`](../convoy-doctor-structure/README.md) so a can-work regression is
caught by the gate, not a human dry-run. That's exactly the class that just bit us: the host-prefix bus-id + kick
sender-robustness bugs (convoy #64) both broke the CoS/delegation boot.

## Two layers

- **CAN-WORK ORG-PROOF CORE (live, gated — `fixture/spin.sh`):** on a well-formed net, `convoy doctor --full` runs
  the real CoS→sup→worker org. The **hard gate** is the **org-proof core** — `g1` (CoS hands-off boot) + `cos→sup`
  + `sup→wk` + `graded_fix` — which is **straddle-independent**. `rc`, the PASS-**headline** ("the full autonomous
  org works on this machine …") and the restart **straddle** (G4/G5) are **ADVISORY, not gated**: convoy confirmed
  `checkFullOrg` returns **one** pass/fail for G1..G5, so a straddle flake fails the whole check → `rc=1` + the ✗
  FAIL headline. The straddle is known-flaky in the hosted run (agent re-engagement, not a code bug), so gating on
  `rc` or the headline would make the eval flaky. They're promoted to hard gates once convoy makes the straddle
  deterministic. Markers: interim `[full-org]` prose, switching to convoy's stable token line
  (`[full-org] GATE g1=pass cos_sup=pass sup_wk=pass graded_fix=pass straddle=pass`) when its follow-up lands.
- **PREFLIGHT FAILS-CLOSED (box-free — `fixture/probe.sh`):** `convoy doctor --full --network <malformed>` exits
  **`rc=1`** via a preflight structure ✗ that short-circuits **before** the org proof spawns. Labeled precisely: a
  **PREFLIGHT** negative, **not** proof the org grader catches a bad fix.

## Honest scope (v1 — external mutation knob DECLINED by Nathan)

`doctor --full` makes its **own** isolated sandbox for the org proof and **ignores `--network`** for it (`--network`
scopes only the preflight). So there's no external handle to force a bad worker fix. The can-work-**grader**
mutation-validity is a **durable, held-out test** that already lives in convoy —
`src/doctor/fixtures/grader/ghost-bug-regression.mjs`: `doctor --full` runs it against **both** the worker repo
(must **pass**) **and** the pristine buggy fixture `src/doctor/fixtures/ghost-bug/` (must **fail**), proving the
grader actually detects the bug (ungameable — it targets the exact call interaction the fixture's green suite never
exercises + lives outside the repo). This cell **cross-references** that concrete test. A force-bad-fix path in
shipped `doctor` is a footgun, so a true **external** can-work mutation knob was **declined by Nathan** (via
cos-relay) — the durable `ghost-bug-regression.mjs` cross-ref is the mutation-validity handle.

## Critical isolation

doctor is scoped with **`--network <sandbox>`** and ambient `ST_ROOT`/`PTY_ROOT`/`CONVOY_NETWORK` are **unset**; the
`--full` org proof runs in doctor's own sandbox and is torn down. Never touches the live fleet.

## Run it

`fixture/probe.sh <SB>` then `fixture/grade.sh <SB>` for the box-free floor; `fixture/spin.sh <SB>` to exercise the
heavy can-work headline (gated). See `task.toml` for the full spec.
