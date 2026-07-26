# fork-in-the-road-codex — the design-panel cell (codex twin)

**Discriminates:** the same design panel as [fork-in-the-road](../fork-in-the-road/README.md), run by **codex**
agents (gpt-5.6-sol) reading `AGENTS.md` — a cross-model probe: does codex complete the 4-agent design panel where
claude does? N distinct approaches, a real debate, a justified recommendation, and the cross-human privacy crux.

## Run it (st2 folder-eval)

```sh
st2 eval ./cells/fork-in-the-road-codex/
```

`fork-in-the-road-codex.kdl` copies the fixture (four dirs — `sup/`, `a/`, `b/`, `c/`, each an agent's own git
workspace with the shared `PROBLEM.md`; `_git` → `.git` on copy) and boots `fd.sup` plus three proposers.
Every workspace intentionally pre-seeds a complete `AGENTS.md` persona. The KDL uses native bare `ding`,
with no authored bus path or compatibility wake command. Requirements: `codex,st2,pty,git`.

## Grading (held-out judges in `judges/`)

The same 5 held-out judges as the base cell: **isolation** (per-lane author), **deliverables** (≥2 PROPOSAL.md +
RECOMMENDATION.md), **distinct** (real option space), **PRIVACY HOOK** (the crux surfaced), **recommendation** (a
justified call on the bus).

Free preflight: `bin/check-codex-native.sh cells/fork-in-the-road-codex` and
`bin/check-codex-reset.sh cells/fork-in-the-road-codex`.

Static readiness, expected cost, and the pending current-build smoke are tracked in
[`../../CODEX-READINESS.md`](../../CODEX-READINESS.md). The live command is opt-in and currently held.
