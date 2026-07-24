# fork-in-the-road — the design-panel cell

**Discriminates:** a team designs how MULTIPLE humans share one agent team — N genuinely distinct approaches, a
real debate, a justified recommendation, and (the held-out discriminator) independently surfacing the cross-human
**privacy / information-isolation** crux. No product code — the deliverables are design docs.

## Run it (st2 folder-eval)

```sh
st2 eval ./cells/fork-in-the-road/
```

The whole eval is `fork-in-the-road.kdl`. `st2 eval` copies the fixture (four dirs — `sup/`, `a/`, `b/`, `c/`,
each an agent's own git workspace with the shared `PROBLEM.md`; `_git`→`.git` on copy) and boots a 4-agent team:
`fd.sup` (synthesizer, owns only `RECOMMENDATION.md`) + `fd.a` / `fd.b` / `fd.c` (proposers). The kick (a design
request from `requester`) goes to `fd.sup`; the debate flows over the smalltalk bus. Caps: `claude,st,pty,git`.

## Grading (held-out judges in `judges/`)

All five are held-out + mechanical:
- **isolation** — each dir is authored only by its owning agent (`fd.<role>`); nobody edits another's dir.
- **deliverables** — ≥2 non-empty `PROPOSAL.md` (a/b/c) committed AND a non-empty `RECOMMENDATION.md` (sup).
- **distinct** — the proposals are a real option space (≥2 distinct, not near-duplicate texts).
- **PRIVACY HOOK** — cross-human privacy / information-isolation is surfaced as a first-class tradeoff (the naive miss).
- **recommendation** — a justified recommendation reached the requester on the bus.

The sup persona carries the no-early-ack rule (send `requester` exactly one final message after the panel is done)
so the done-detector isn't tripped by an interim ack.
