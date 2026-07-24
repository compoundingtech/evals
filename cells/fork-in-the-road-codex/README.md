# fork-in-the-road-codex — the design-panel cell (codex twin)

**Discriminates:** the same design panel as [fork-in-the-road](../fork-in-the-road/README.md), run by **codex**
agents (gpt-5.6-sol) reading `AGENTS.md` — a cross-model probe: does codex complete the 4-agent design panel where
claude does? N distinct approaches, a real debate, a justified recommendation, and the cross-human privacy crux.

## Run it (st2 folder-eval)

```sh
st2 eval ./cells/fork-in-the-road-codex/
```

`fork-in-the-road-codex.kdl` copies the fixture (four dirs — `sup/`, `a/`, `b/`, `c/`, each an agent's own git
workspace with the shared `PROBLEM.md`, `AGENTS.md` personas since codex reads AGENTS.md; `_git`→`.git` on copy)
and boots 4 codex agents: `fd.sup` + `fd.a` / `fd.b` / `fd.c`, each `exec codex
--dangerously-bypass-approvals-and-sandbox --model gpt-5.6-sol` with a `st2 ding` wake sidecar. Caps: `codex,st,pty,git`.

## Grading (held-out judges in `judges/`)

The same 5 held-out judges as the base cell: **isolation** (per-lane author), **deliverables** (≥2 PROPOSAL.md +
RECOMMENDATION.md), **distinct** (real option space), **PRIVACY HOOK** (the crux surfaced), **recommendation** (a
justified call on the bus).

Committed as the codex twin (unproven — its Decision-2 disposition is Nathan's call; the probe run's finding was a
codex delegation-stall distinct from the claude persona gap).
