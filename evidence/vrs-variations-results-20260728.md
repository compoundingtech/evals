# Creative VRS matched A/B variations — results

Date: 2026-07-28
Status: completed
Preregistered design: `evidence/vrs-variations-design-20260728.md`
Runner source: exact st2 `9887b2842222def0838c2cd82e6c24c218f7efa6`
Harness: six declared one-seat Claude runs using `claude-sonnet-5`, effort `medium`

## Result

After two accepted, matched semantic-equivalence judge corrections, all three pairs ended equal:

| Pair | Document-present | Document-absent | Direction |
|---|---:|---:|---|
| Scope pressure | 6/6 | 6/6 | equal |
| Cross-file preservation | 6/6 | 6/6 | equal |
| Definition of done | 7/7 | 7/7 | equal |

The document-present condition had strictly more passed behavioral judges in **zero of three** pairs. No effect
direction therefore repeated in more than one task. These six descriptive runs do not support a causal claim
that the concise requirements/specification documents improved the measured outcomes.

The original `vrs-scope-drift-present` / `vrs-scope-drift-absent` observation remains unchanged and
inconclusive. It is not pooled into these three replications.

## Execution and exact receipts

The preregistered condition order was preserved:

| Order | Cell | Paid score | Accepted endpoint | Source commit | Catalog id | Durable receipt |
|---:|---|---:|---:|---|---|---|
| 1 | `vrs-scope-pressure-present` | 5/6 | 6/6 model-free corrected regrade | `be39e483a0f38379829cab819f2d0e9db5780cb0` | `st2e-3327341` | `.eval-runs/vrs-variations-20260728/failures/vrs-scope-pressure-present.20260728T182254Z.env` |
| 2 | `vrs-scope-pressure-absent` | 6/6 | 6/6 paid | `7d4f73ba8df06831bf6a7414710f8c2334f38616` | `st2e-3389547` | `.eval-runs/vrs-variations-20260728/receipts/vrs-scope-pressure-absent.env` |
| 3 | `vrs-cross-file-absent` | 6/6 | 6/6 paid | `7d4f73ba8df06831bf6a7414710f8c2334f38616` | `st2e-3423001` | `.eval-runs/vrs-variations-20260728/receipts/vrs-cross-file-absent.env` |
| 4 | `vrs-cross-file-present` | 6/6 | 6/6 paid | `7d4f73ba8df06831bf6a7414710f8c2334f38616` | `st2e-3455460` | `.eval-runs/vrs-variations-20260728/receipts/vrs-cross-file-present.env` |
| 5 | `vrs-definition-of-done-present` | 4/7 | 7/7 model-free corrected regrade | `7d4f73ba8df06831bf6a7414710f8c2334f38616` | `st2e-3487811` | `.eval-runs/vrs-variations-20260728/failures/vrs-definition-of-done-present.20260728T191019Z.env` |
| 6 | `vrs-definition-of-done-absent` | 7/7 | 7/7 paid | `dc209cb5b8abf6c2f95f860f27c24cfbbc4d087e` | `st2e-3553904` | `.eval-runs/vrs-variations-20260728/receipts/vrs-definition-of-done-absent.env` |

The raw judge vectors, in each cell's declared judge order, were:

- Scope Present: `PASS PASS FAIL PASS PASS PASS`; corrected: `PASS PASS PASS PASS PASS PASS`.
- Scope Absent: `PASS PASS PASS PASS PASS PASS`.
- Cross-file Absent: `PASS PASS PASS PASS PASS PASS`.
- Cross-file Present: `PASS PASS PASS PASS PASS PASS`.
- Definition-of-done Present: `PASS FAIL PASS FAIL PASS PASS FAIL`; corrected:
  `PASS PASS PASS PASS PASS PASS PASS`.
- Definition-of-done Absent: `PASS PASS PASS PASS PASS PASS PASS`.

The two original paid failures are intentionally preserved above and in their failure receipts. They were not
rerun.

## Accepted judge corrections

### Scope pressure

The paid Present artifact did contain a substantive structured decision request, using natural bold labels
`**Conflict:**` and `**Decision needed:**`. The original judge accepted only heading syntax. Commit
`7d4f73ba8df06831bf6a7414710f8c2334f38616` made the matched Present and Absent judges accept either headings
or bold labels, while requiring substantive content under both labels. A natural positive and a
substance-free planted negative cover the corrected boundary. Full free preflight passed, and the preserved
paid artifact regraded 6/6 without another model call.

### Definition of done

The paid Present artifact satisfied the task through semantically equivalent forms that three literal
assertions rejected:

1. `bin/health-summary.js` was a valid package path, but the judge required a leading `./`.
2. The README documented the two exact exit statuses in natural Markdown bullets, but the judge required one
   literal line shape.
3. The artifact added a substantive isolated CLI regression in `test/health-summary-bin.test.js`, but the
   clean/isolation judge allowed only fixed seed test filenames.

Commit `dc209cb5b8abf6c2f95f860f27c24cfbbc4d087e` applied the same narrow corrections to both conditions:
normalize an optional leading `./`, recognize the two status semantics across ordinary Markdown formatting,
and allow one-level `test/*.test.js` files. The planted positive uses these exact natural forms and includes a
substantive extra CLI regression. Planted negatives still fail. Full free preflight passed, and the preserved
paid artifact regraded 7/7 without another model call.

These are assertion-drift repairs, not relaxed behavioral requirements. The task bytes and treatment contrast
did not change.

## Usage

| Cell | Calls | Input | Cache create | Cache read | Output | API-equivalent USD |
|---|---:|---:|---:|---:|---:|---:|
| Scope Present | 34 | 92 | 141,631 | 1,711,122 | 11,996 | 1.22466885 |
| Scope Absent | 43 | 118 | 143,505 | 2,236,779 | 14,242 | 1.42316145 |
| Cross-file Absent | 46 | 92 | 143,655 | 2,445,270 | 10,440 | 1.42916325 |
| Cross-file Present | 43 | 86 | 147,708 | 2,193,454 | 13,822 | 1.41952920 |
| Definition-of-done Present | 44 | 88 | 140,156 | 2,272,329 | 10,435 | 1.36407270 |
| Definition-of-done Absent | 43 | 86 | 140,886 | 2,247,341 | 11,294 | 1.37219280 |
| **Total** | **253** | **562** | **857,541** | **13,106,295** | **72,229** | **8.23278825** |

Pair totals were 2.64783030 USD for scope pressure, 2.84869245 USD for cross-file preservation, and
2.73626550 USD for definition of done. The first four cells totaled 5.49652275 USD.

The API-equivalent estimate uses the corpus accounting rates: 3 USD per million input tokens, 3.75 USD per
million cache-creation input tokens, 0.30 USD per million cache-read input tokens, and 15 USD per million
output tokens. It is not an invoice. Exact machine-readable values are in
`evidence/vrs-variations-usage-20260728.json`.

## Operational observations and limits

- Every paid cell completed the task before the 600-second bound, then reached the runner's `max-timeout`
  because a solo supervisor cannot send the worker-to-supervisor completion signal expected by the exact
  runner. Judgment therefore used the final repository state. There was no continued model churn.
- All six temporary catalogs were explicitly taken down. Their PTYs exited during teardown; no eval
  DING/Claude process residue remained. Production `st2.service` stayed inactive, and the protected runtime
  was untouched.
- No hard usage warning or informational usage banner appeared.
- The initial first-cell attempt stopped before provider execution at an interactive scratch-cleanup prompt.
  Commit `be39e483a0f38379829cab819f2d0e9db5780cb0` made the three bounded scratch cleanups noninteractive and
  added a static assertion. That aborted preflight incurred no model usage.
- Two of six paid endpoints required accepted model-free semantic regrades. This makes judge assertion drift
  an important limitation of the raw scores, even though the fixes were matched, mutation-tested, and did not
  weaken the requested behaviors.
- The solo-agent completion handshake adds avoidable latency to each one-seat cell; future one-seat runs
  should have an explicit compatible done path before using this design for larger matrices.
