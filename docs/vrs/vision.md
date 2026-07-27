# evals vision

## The Problem

1. **Agent work is running on vibes instead of cumulative proof.** Plausible
   patterns spread without building on what has been proven to work. The only
   way to establish behavior that future work can reliably build on is an
   automated, reproducible test.
2. **Aspirational agent specifications are easy to write and hard to trust.**
   A plausible document can describe behavior no real harness or agent can
   execute.
3. **Agent experiments can hide cost and weak evidence.** Defaults, hooks,
   fixtures, judges, cleanup, and provider usage can silently change the result.

## The Vision

- Iterate toward an ideal agent spec by authoring executable agent-spec evals
  and scenarios.
- Extract the written agent spec from real executable behavior that works well.
- Prove agent ideas with reproducible evidence, not vibes.
- Make the path from a new agent idea to a runnable eval fast enough for normal
  design iteration.
- Converge on one execution model where every agent and agent run is
  expressible as an eval and the current runtime executes both evaluated
  scenarios and ordinary agent work.

## What This Is Not

- A speculative standards process that defines a complete agent system before
  the behavior works.
- A provider leaderboard or permission to maximize model spend.
- A requirement that every judge be deterministic; valid LLM and cross-model
  judges remain supported.

## Success Criteria

1. Every normative agent-spec claim traces to maintained executable evidence.
2. Proposed behavior is added to the spec only after an eval demonstrates it,
   and failed ideas remain visible as evidence rather than becoming doctrine.
3. A full maintained-corpus run is bounded, resumable, cleans up every launched
   agent, and reports model, effort, usage, and cost.
4. The same scenario can expose meaningful harness differences without hidden
   changes to hooks, personas, fixtures, or grading.
5. An author can turn a new idea into a validated, runnable eval without
   changing runner code or creating one-off infrastructure.
6. Every declared agent and ordinary agent run can be represented as an eval
   executed by the current runtime, with explicit inputs, hooks, model,
   lifecycle, evidence, cleanup, and receipts.
