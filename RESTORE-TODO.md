# Restore / Parked TODO — cells deferred pending a capability or a layer decision

Cells here are **not retired** — each is valuable and comes back once the capability or layer it depends
on exists. Restore/port any from git history: `git log --oneline -- cells/<name>`.

## Parked pending the ONBOARDING / init path (not yet built in st2)
st2 has no imperative onboarding/init/interview command yet — the workflow is: author st2 spec files +
run them. Cells that test the *newcomer stands up a network/CoS from zero* path wait for that path.

- **first-run** — REMOVED (git-rm'd), restore-soon (Nathan's words). The stranger-onboarding + **no-leak**
  eval: clone the SHA-pinned public personas repo (read-only), run a scripted first-run interview, end
  with a committed **private** CoS repo joined to a fresh network — headlined by the NO-LEAK gate.
  Restore + port to the folder format once the onboarding path exists. Highest-priority restorable.
- **bootstrap-network** — KEPT in `cells/` (old format), PARKED. The newcomer "Alex" zero-to-network path:
  init a fresh network, CoS boot ritual, CoS spawns a specialist (harness bootstrap: identity + hooks +
  session), end-to-end message. Its deliverable is the FRICTION LIST (where docs diverge from reality),
  which is *about* the missing init/onboard commands — so it ties to the same deferred onboarding path,
  not just `st2 up`. (Contrast: **convoy-network** = does `st2 up` *host* a network — that ports now.)
  Port when the st2 onboarding path exists.

## Parked pending the WORKSPACE-PREP layer (open question: what cuts worktrees in the new stack)
- **worktree-cutting** — KEPT in `cells/` (old format), PARKED. Tests cutting a real linked git worktree
  per agent (bare canonical + linked worktrees). This is UPSTREAM of st2's run charter — render/nix owns
  workspace-prep, st2 just runs what is rendered. Do NOT force it into an st2 eval. Nathan + the CoS will
  settle what cuts worktrees in the new stack; port it to that layer's test surface once decided.

## Removed, no restore planned (documented for provenance)
These test imperative st2 commands Nathan is not building (the workflow is author spec files + run them).
Restorable only if those commands are ever added:
- **convoy-add-structure** — tested `convoy add` producing a seat overlay; no `st2 add` planned.
- **convoy-init-structure** — tested `convoy init <net>` producing the network layout; no `st2 init`.
- **convoy-init-narration** — tested `convoy init`'s narration / `--quiet` / `--json`; no `st2 init`.
