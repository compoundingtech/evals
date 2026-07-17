# convoy-doctor-teardown — a SIGTERM-killed `convoy doctor --full` reaps its org (no abort-leak)

**Discriminates:** when `convoy doctor --full` is **aborted mid-org** (a CI-timeout SIGTERM or a ctrl-c SIGINT),
does it run its finally-teardown and **reap its whole CoS→sup→worker org** (agents + ding sidecars) before exit — or
does the killed signal skip the teardown and **leak the org** into a now-deleted sandbox? (held-out; no LLM)

**Capabilities required:** `claude,convoy,st,pty,git` · run `bin/st-evals preflight`. Live/gated (heavy: a real org).

## What it proves (guards convoy #67)

`doctor --full` is the 15-20min org proof that gets **CI-timeout-killed**. Pre-#67, that SIGTERM skipped the
`finally` teardown → the whole org (real `claude` agents + their ding sidecars) survived **orphaned** into a deleted
sandbox — observed for real (a run-#1 timeout leaked **5 sessions** in `cvd-full-gYnbzd`). Convoy #67 traps
SIGTERM/SIGINT (`suite.ts`: *"SIGTERM received — tearing down the sandbox org before exit…"*) and `convoy down`s the
sandbox first. This cell locks that in so an abort-leak can't silently come back.

> This is the **abort-path** guard. A **normal** exit + a plain `convoy down` already reap the org+ding cleanly
> (convoy #30 confirmed) — that isn't the gap; the abort path, where the `finally` never runs, is.

## One run, self-contained + mutation-valid

`fixture/spin.sh` launches `doctor --full` in the background, waits for the org-up marker
(`[full-org] real chief-of-staff spawned; convoy up hosting` — the earliest a real org exists to leak) + a short
settle, then:

- **counts the sandbox's live org sessions BEFORE the abort** — must be `>0` (a real org is live, and the
  leak-detector is not vacuously always-0). **This before>0 vs after=0 contrast is the mutation-validity**, on one
  convoy — no pre-#67 build needed.
- **SIGTERMs the `--full`** (the CI-timeout abort; `convoy` is a node script, so `SIGTERM $!` reaches its trap).
- **counts AFTER** — must be `0` + the **sandbox swept**: the #67 trap reaped the whole org.
- **guaranteed self-cleanup** of any residual leak, so a RED never leaves stragglers.

Grades on **teardown, not rc** (convoy's trapped rc is 130 — an impl detail we don't pin).

## Critical isolation

The org runs in doctor's **own** sandbox; counts are scoped to that sandbox dir + its pty root, and the cell reaps
any leak it detects — the operator's **real fleet is never touched**.

## Run it

`fixture/spin.sh <SB>` then `fixture/grade.sh <SB>`. See `task.toml` for the full spec. Sibling:
[`convoy-doctor-canwork`](../convoy-doctor-canwork/README.md) — the can-work proof; this guards that the same
`--full` cleans up when **aborted**.
