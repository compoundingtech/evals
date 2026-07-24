# Restore / Parked TODO — cells deferred pending a capability or a layer decision

Cells here are **not retired** — each is valuable and comes back once the capability or layer it depends
on exists. Restore/port any from git history: `git log --oneline -- cells/<name>`.

> **2026-07-23 — Nathan-signed-off removal batch (6 cells git-rm'd).** Per PORT-not-retire, Nathan approved
> removing: bootstrap-network, convoy-doctor-preinit, convoy-worktree-cutting (feature/layer not built yet —
> restore later); convoy-doctor-canwork, convoy-doctor-teardown (FOLDED — coverage preserved by team-standup);
> convoy-doctor-foreign-box (RETIRED — genuine no-st2-analog). All restorable from git history. Details in the
> sections below (each marked **REMOVED 2026-07-23**).

## Parked pending the ONBOARDING / init path (not yet built in st2)
st2 has no imperative onboarding/init/interview command yet — the workflow is: author st2 spec files +
run them. Cells that test the *newcomer stands up a network/CoS from zero* path wait for that path.

- **first-run** — REMOVED (git-rm'd), restore-soon (Nathan's words). The stranger-onboarding + **no-leak**
  eval: clone the SHA-pinned public personas repo (read-only), run a scripted first-run interview, end
  with a committed **private** CoS repo joined to a fresh network — headlined by the NO-LEAK gate.
  Restore + port to the folder format once the onboarding path exists. Highest-priority restorable.
- **bootstrap-network** — **REMOVED 2026-07-23** (git-rm'd, Nathan-signed-off; restore later). The newcomer "Alex" zero-to-network path:
  init a fresh network, CoS boot ritual, CoS spawns a specialist (harness bootstrap: identity + hooks +
  session), end-to-end message. Its deliverable is the FRICTION LIST (where docs diverge from reality),
  which is *about* the missing init/onboard commands — so it ties to the same deferred onboarding path,
  not just `st2 up`. (Contrast: **st2-network** = does `st2 up` *host* a network — that ports now.)
  Port when the st2 onboarding path exists.

## Parked pending the WORKSPACE-PREP layer (open question: what cuts worktrees in the new stack)
- **worktree-cutting** (`convoy-worktree-cutting`) — **REMOVED 2026-07-23** (git-rm'd, Nathan-signed-off; restore when the workspace-prep layer is decided). Tests cutting a real linked git worktree
  per agent (bare canonical + linked worktrees). This is UPSTREAM of st2's run charter — render/nix owns
  workspace-prep, st2 just runs what is rendered. Do NOT force it into an st2 eval. Nathan + the CoS will
  settle what cuts worktrees in the new stack; port it to that layer's test surface once decided.

## Folded — coverage preserved elsewhere (Nathan-signed-off 2026-07-23)
- **restorability** + **restorability-codex** — **REMOVED 2026-07-23** (git-rm'd, Nathan-signed-off). FOLDED: its
  cold-restart-WITHOUT-resume reconstruct is exactly what **restart-continuity** already proves (cold respawn from
  spec + lossless resume from the durable substrate, no item skipped). Its distinct "no stale CC input-queue"
  discriminator is STRUCTURALLY ABSENT in st2 — `st2 up` always respawns COLD (never `--resume`), so it cannot
  restore a stale input-queue (honest-by-construction, same shape as convoy-doctor-foreign-box). Nothing left to
  port distinctly. Restore from git history only if st2 ever gains a `--resume`/session-preservation path.

## Removed — the idea lives on as a real project, not an eval (Nathan-signed-off 2026-07-24)
- **tui-build** — **REMOVED 2026-07-24** (git-rm'd, Nathan-signed-off). NOT retiring the idea: the greenfield
  "team builds a real terminal UI over the agent network" is becoming an ACTUAL post-swap project — a live agent
  team building a real TUI on the new kdl specs after the st2 swap — rather than a self-graded eval. So
  tui-build-as-an-eval is removed; the real TUI is the follow-on work. Restorable from git history.

## Removed, no restore planned (documented for provenance)
These test imperative st2 commands Nathan is not building (the workflow is author spec files + run them).
Restorable only if those commands are ever added:
- **convoy-add-structure** — tested `convoy add` producing a seat overlay; no `st2 add` planned.
- **convoy-init-structure** — tested `convoy init <net>` producing the network layout; no `st2 init`.
- **convoy-init-narration** — tested `convoy init`'s narration / `--quiet` / `--json`; no `st2 init`.

---

## Doctor cells — reassessed against `st2 doctor` (Nathan-signed-off 2026-07-23)
`st2 doctor` health-checks a RUNNING catalog (PATH + supervisor host-lock + agent tasks alive + presence);
it is read-only and has NO auth/sign-in/hooks probe (that was convoy-doctor-specific). Outcomes:
- **convoy-doctor-structure** — PORTED to `st2 doctor` (committed 909b17f, 4/4: healthy net → all-checks-passed exit 0; broken net → ✗ supervisor + non-zero). KEPT.
- **convoy-doctor-canwork** — **REMOVED 2026-07-23** (git-rm'd, Nathan-signed-off). FOLDED into team-standup (both = a CoS stands up an org + a graded fix; team-standup proves it, 4/4). Restore only if a distinct doctor-canwork surface is ever wanted.
- **convoy-doctor-teardown** — **REMOVED 2026-07-23** (git-rm'd, Nathan-signed-off). FOLDED — its "killed doctor reaps its org (zero-orphans)" capability is proven by team-standup's PTY_ROOT-scoped supervise teardown reap.
- **convoy-doctor-preinit** — **REMOVED 2026-07-23** (git-rm'd, Nathan-signed-off; restore with the onboarding/init path). A fresh-user pre-init doctor pointer; no `st2 init` — same bucket as first-run/bootstrap-network above.
- **convoy-doctor-foreign-box** — **REMOVED 2026-07-23** (git-rm'd, Nathan-signed-off). RETIRED — genuine no-st2-analog: it discriminated honest degradation on an inconclusive AUTH probe, but `st2 doctor` has no auth probe (honest-by-construction — it only checks directly-observable state). Restorable only if an auth/sign-in probe is ever added to `st2 doctor`.
