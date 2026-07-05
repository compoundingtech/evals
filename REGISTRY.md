# Cell registry

The catalogue of every st-evals cell: its SDLC work-type, the **discriminator** (the specific thing a
weak team fails), the **held-out** check that makes it un-gameable, and the capabilities it needs. This
is a gallery of *cell types* — it intentionally carries no graded run-history against any private network
(those verdicts stay private). Run `bin/st-evals preflight` to see which of these your setup can run.

Legend — caps: **C** claude · **X** codex · **G** ollama+GLM · **st** the bus · **pty** sessions ·
**node** · **git** · **net** network-once. Cross-family judging needs ≥2 families installed.

---

## SDLC work-types (team cells, six-axis graded)

| Cell | Type | Discriminator | Held-out acceptance | Caps |
|---|---|---|---|---|
| **ghost-bug** | debug | root-cause a shared-default **aliasing** mutation vs paper over it (freeze/reset) | the new regression test must **FAIL on the base buggy commit**, pass after | C·st·pty·git·node |
| **poisoned-pr** | review | catch what green CI misses — especially a **planted security hole** — and return request-changes, not a rubber-stamp | repo must be **unmodified** (review lane held); defects verified by *running*, not eyeballing | C·st·pty·git·node |
| **incident-response** | incident | the **ROOT** fix under urgency, not a band-aid that stops the 500 but ships wrong values | independent nearest-rank **correctness gate** + a mutation-valid regression test | C·st·pty·git·node |
| **migration** | dependency-bump | migrate **every** call site + **don't silently drop** removed APIs (reimplement, don't delete); leave the unchanged API alone | suite green + the baseline test file **byte-identical** (tests not weakened) | C·st·pty·git·node |
| **security-audit** | audit | proactive whole-repo **input→sink** tracing + severity calls + **dismiss the red-herrings** (signal vs noise); read-and-report, don't "fix" | product `src/` **byte-identical** to base; per-vuln coverage; the high-severity findings are hard gates | C·st·pty·git·node |
| **feature-fit** | feature | add a feature **idiomatically indistinguishable** from the existing code (reuse the existing result/validate helpers), not a working-but-alien bolt-on | fit greps catch a functional-but-unidiomatic solution the functional gate alone would pass | C·st·pty·git·node |
| **docs** | docs | an explain-it doc that surfaces the **non-obvious contracts** a reader can't guess from names | a fresh **cold-reader** agent, given only the docs + a black-box lib, must produce the right answer | C·st·pty·git·node |
| **test-writing** | tests | a regression-catching suite with **exact-value + boundary** assertions, not coverage theater | a **mutation score** — the tests must KILL planted mutants; high line-coverage alone fails | C·st·pty·git·node |
| **fork-in-the-road** | design | generate **N genuinely distinct** approaches → a productive debate (real on-record changes of mind) → a **justified** recommendation + **escalate** the values call | did the panel independently surface the held-out **privacy** crux? (a judge-panel shape, not delegate→execute) | C·st·pty·git |
| **license-mit** | team loop | the **smallest** delegate→execute→verify→confirm loop; the supervisor must **not** edit the worker's repo | isolation from git metadata (only the owner commits); canonical MIT, tree clean — the **matrix** cell (runs C/X/G/mixed) | C·st·pty·git |
| **tui-build** | greenfield build | a team builds a real TUI over the agent network (two views + one shared data layer) + a **human-centered usability find→fix pass** — not just "it renders" | isolation by lane (the reviewer writes no code); **held-out cold-nav** (render the built views on a frozen synthetic network) + a **usability rubric** the team never sees; a frozen fixture plants the edge cases (an `away` status the seed type omits, overflow, empty, stale-unknown) | C·st·pty·git·node |
| **restart-continuity** | durability | a **cold-restarted** worker resumes an ordered batch **losslessly** — a scripted restart is injected mid-batch (after the item-2 commit) and the agent must pick up from durable ground truth alone | **at-least-once**: NO ITEM SKIPPED (every id done ≥1× with a working handler) is the hard gate; no corrupting redo (suite green, no dup dispatch keys); commits must **straddle** the restart (resumed, not front-loaded); a clean duplicate is tolerated. Isolation survives the restart (same identity → same git author) | C·st·pty·git·node |
| **hook-integrity** | launch-integrity (diagnostic) | prove a Claude agent's **SessionStart hook FIRES** on launch — not just that it's *configured* (reading `settings.local.json` proves config, which was true in the field case this comes from — hooks configured, silently never run) — via an **ungameable rehydrate-token**: a secret seeded ONLY into `context/now.md`, which the hook injects as a `<context>` block iff it runs | **hooks-on → the token appears in `HOOK_OK.txt`; hooks-off (`--no-hooks`, MCP still on) → it does NOT.** The difference is the proof (a check that passes both ways tests nothing); the token is random per run so no fixture edit pre-satisfies it. Standalone **single-command, loud PASS/FAIL banner**; a minimal persona never names the token so a pass is attributable only to the hook | C·st·pty·git |
| **ding-mode** | no-MCP participation | is **ding-only first-class**? a fully no-MCP Claude team (`st launch claude --ding`) coordinates a real delegate→execute→report→verify task over the `st ding` sidecar (`[DING] ` pokes) + the `st` CLI — the no-MCP / locked-down-host shape | grades the **experience**, not just delivery: boot ritual drains the kick over the CLI (no MCP); the `[DING]`-delivered delegation is read+archived+replied; the loop is bus-visible; task correct (slugify meets spec, held-out) + **no `.mcp.json`** in either dir + isolation. Rescues = 0 is the headline. Also the acceptance test for `st launch claude --ding` | C·st·pty·git·node |

---

## Cross-family variants

The same scenario, run **model-family-native**, is how the suite isolates *system* from *model*. A
full-Codex (or GLM, or mixed) team must reach the same graded outcome as the Claude team.

| Cell | Base | Family | Notes |
|---|---|---|---|
| **ghost-bug-codex** | ghost-bug | Codex | AGENTS.md persona; `ding` wake sidecar (no asyncRewake); pre-trust dirs |
| **poisoned-pr-codex** | poisoned-pr | Codex | same review discriminator; cross-family severity-calibration differences are a feature to observe |
| **fork-in-the-road-codex** | fork-in-the-road | Codex | distinct per-panelist git author; prior-cell content quarantined so convergence is genuine |
| **license-mit-codex** | license-mit | Codex | full-Codex team on the smallest loop; distinct worker git author → isolation provable from commit metadata; `ding` wake sidecar |
| **license-mit** *(matrix)* | — | C / X / G / mixed | one task/world, four compositions; the only variable is which family fills each seat |

> **The matrix claim.** `license-mit` is the anchor: the identical task and world, run by a Claude team,
> a Codex team, a GLM team, and a mixed Claude-supervisor/Codex-worker team. When all four produce the
> same coordinated, isolation-respecting result, "it's the system, not the model" stops being a slogan.

---

## Onboarding + team-formation (per-gate graded; deliverable = a friction list)

| Cell | Proves | Caps |
|---|---|---|
| **bootstrap-network** | zero → a working network: init a fresh `ST_ROOT` → a CoS comes online → boot ritual (status + inbox drain) → CoS **spawns a specialist** → they message end-to-end (incl. an identity-leak kill-test) | st·pty·git |
| **first-run** | the real "stand this up on your machine" chain: consume the **public personas repo, SHA-pinned** (read-only) → run the first-run interview (scripted synthetic principal) → a committed **private** CoS repo that joins the network. Headline gate: **no-leak** (private data never touches the public checkout, which stays byte-identical at the pin) | st·git·net |
| **team-standup** | the manager can stand up a **working team**, not just itself: the interviewed CoS **stands up a specialist** (`st launch`) → **delegates** a real unit over the bus → the specialist executes in its **own repo** + reports → the CoS **walks it read-only** + confirms (verifies, doesn't rubber-stamp). Isolation is the hard gate; the whole delegate→execute→report→walk loop is bus-visible. Extends bootstrap→first-run | C·st·pty·git·node |

These deliberately try the *documented* path first at each gate — when it fails, that failure **is** the
finding — so the friction list reflects what a newcomer following the docs actually hits.

---

## Held for sign-off (not in the public cut yet)

Two cells are intrinsically tied to specific real repos / a live network and are being de-personalized
separately (a synthetic dependency-graph; a frozen fixture network) before they ship:

| Cell | Type | Why it's held |
|---|---|---|
| **pty-rename** | cross-repo rename | crown-jewel coordination (decomposition + sequencing + judgment across a multi-repo dependency graph) — public version needs a **synthetic** base-package + 2 consumers with an analogous product-vs-primitive naming trap (build in progress) |

They re-appear in `cells.manifest` with their `cells/<cell>/` dirs once cleared.
