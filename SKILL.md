---
name: evals
description: Inspect, validate, or run isolation-gated st2 agent-team eval cells. Use for corpus inventory, free preflight, an explicitly authorized cell run, or adding a held-out-graded cell.
---

# evals

Use the repository's canonical surfaces:

- `AGENT-SPEC.md` for current hand-authored st2 agent declarations;
- `CATALOG.md` for the generated inventory, cost bands, exclusions, and evidence;
- `cells/<cell>/<cell>.kdl` for executable cell behavior.

## Default workflow

Run the free gate first:

```sh
bin/check-corpus.sh
```

Inspect the no-execution overnight plan with:

```sh
bin/overnight.sh --dry-run
bin/overnight.sh --dry-run --cell <cell> --cell <cell>
```

Never infer permission for a paid/model run. When one cell is explicitly authorized:

```sh
st2 eval ./cells/<cell>/ --keep
```

When an exact conservative paid queue is explicitly authorized, repeat `--cell` in the approved order:

```sh
bin/overnight.sh --run --cell <cell> --cell <cell> --state-dir .eval-runs/overnight
```

The common Codex reset-available banner stops the default run before the next cell. A future full unattended
run therefore requires separate human review of both `--all` and the higher-spend informational-banner opt-in:

```sh
bin/overnight.sh --run --all --allow-informational-reset-banner --state-dir .eval-runs/overnight
```

Paid `--run` rejects an omitted selector, duplicate, unknown, retired, and model-free cells. Hard
quota/rate-limit errors stop unconditionally in both modes. Never infer approval for either paid command.

## Cell rules

- One canonical root KDL per cell and one declared `max-timeout`.
- The eval runner owns the native flat bus and pty roots.
- Every model subject and model judge selects its model and medium effort explicitly.
- Every bus-connected model agent uses native bare `ding`, one cold-start drain, and event-first DING wakeups.
- Every Claude workspace materializes the canonical Claude loader/persona/hooks; every Codex workspace
  materializes the canonical AGENTS/hooks and trusts them at launch.
- Fixtures are synthetic and resettable; checked-in Git metadata is frozen as `_git`.
- Graders are held out, ownership-aware, and mutation-valid where practical.
- No paid rerun is a substitute for shell, parse, reset, model-policy, and PII gates.

After changing inventory or structured evidence, run:

```sh
bin/generate-catalog.sh --write
bin/check-corpus.sh
```
