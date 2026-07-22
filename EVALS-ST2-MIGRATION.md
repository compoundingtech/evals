# evals → st2 migration — evals-side analysis

Companion to st2-claude's `EVALS-MIGRATION-PLAN.md`. This is the **evals-repo owner's** side:
the repoint surface, a *proof* that graders are runner-transparent, and a per-cell disposition
for the convoy-mechanism ("Class-2") cells. Approach is settled: **repoint the runner under
`bin/lib-harness.sh`, keep every fixture/persona/kick/grader unchanged** — the same cell that passed
on convoy must pass on st2 (that identity IS the trust gate). st2-claude's ghost-bug pilot already
graded full green (10/0) on st2 via a runner-only swap, so this is proven, not theoretical.

## 1. The repoint surface (choke point)

Every team-loop cell reaches the runner ONLY through these seams in `bin/lib-harness.sh`:

| seam | today (convoy) | st2 leg |
| --- | --- | --- |
| `stev_convoy_init <NET>` | `convoy init` | st2 render creates the bus dirs (no separate init) |
| `stev_pretrust [--harness codex] <dir>…` | `convoy pretrust "$@"` | `st2 pretrust "$@"` (same CLI: merge-not-clobber, one atomic batch write) |
| `stev_convoy_add <id> <dir> <mode> <persona> [harness]` | `convoy add … --persona … --harness …` + `convoy up --once "$NET"` | `st2 render-agent "$NET" --role --identity --dir --persona --harness --host` + `st2 up --once "$NET" --host` |
| `stev_convoy_teardown <NET>` | `convoy down "$NET" --force` | `st2 down "$NET" --host` |
| `stev_seed_kick <NET> <id> <kick>` | `st message send` (host-prefix-resolved) | `st2 message send` / `st message` — smalltalk wire-compatible either way; the host-prefix resolve logic is unchanged |

**Wire status (claude leg): DONE + verified.** `bin/lib-harness.sh` now dispatches every seam on a runner
selector — **`STEV_RUNNER=convoy` (default, prod suite untouched)** vs **`STEV_RUNNER=st2`** (the
candidate). Seam names are unchanged, so **zero cell edits** — the dispatch is internal. `st2` is invoked
through **`ST2_BIN`** (`"${ST2_BIN:-st2}"`), mirroring the existing `CONVOY_BIN` convention, because the
**installed st2 on PATH (`0.1.0`/`0337c31`) PREDATES the migration commits** — it has no `render-agent`
and no `pretrust`. So a gate run must set `ST2_BIN` to a current st2 build/source (st2-claude's pilot ran
from source at HEAD). Host is resolved once (`STEV_HOST` or `hostname -s`) and passed to both
`render-agent` and `up`/`down` — st2's own `--host` default is the local hostname too, so they agree.
Verified: convoy path byte-unchanged; st2 path emits the exact command shapes; `st2 up --once --host` +
`st2 down --host` validated against the installed binary; `render-agent`/`pretrust` shapes built to
st2-claude's stated contract (pending their HEAD confirmation). **Honest guards, not silent fallbacks:**
a `codex`-harness or MCP-forced (`EVAL_MCP=1`) cell FAILS LOUD on the st2 leg (`rc=3`, "run it on convoy")
until st2's codex rig / `render-agent --mcp` land — never a hollow green as claude/ding.

**`stev_pretrust` is new (this change).** `convoy pretrust` was being called **raw in 23 team-loop
`spin.sh` files** — not wrapped — so a pretrust repoint meant editing 23 files. It is now a single
seam: cells call `stev_pretrust`, the body delegates to `convoy pretrust` today, and the st2 swap is a
one-line change. Behavior-preserving on convoy (verified: args — variadic dirs AND `--harness codex` —
pass through verbatim).

**Persona (verbatim passthrough) — confirmed.** The eval composes ONE standalone persona file itself
(`compose-persona.sh`: task-lane + boot ritual + SHA-pinned BASE + role). The runner only installs it
as-is (`PERSONA.md` / `AGENTS.md`) and @-imports it. st2 render byte-installs it verbatim (pilot
byte-compared it) — the `--persona` contract is met, SHA-pin reproducibility holds. Requirement on the
st2 leg: a `--persona <file>` verbatim passthrough (not compose-from-fragments), and codex parity
(`AGENTS.md`).

**PTY_ROOT** stays a short decoupled export (`stev_pty_root`, ~104-byte unix-socket limit); st2 will
honor the ambient `PTY_ROOT` for its own pty ops (st2-side G2/G3), matching convoy.

## 2. Grader-coupling sweep (proof, not belief)

Swept all **42 `grade.sh`** files for any runner coupling. Two coupling classes exist:

- **(a) Bus reads** — `$SB/st-root/smalltalk` + host-prefix `<host>.<id>` tolerance (graders'
  `busdir()`/`msgs_from()` already tolerate prefixed *and* bare ids). Resolves by **convention**: render
  the catalog at `<sandbox>/st-root` so `$CATALOG/smalltalk == <sandbox>/st-root/smalltalk`, files named
  `<epoch-ms>-<sfx>.md` with `from:`/`to:` headers. Keep that shape → graders untouched.
- **(b) Runner registry / isolation probes** — `pty ls` / `convoy ls` used to assert "no eval session
  leaked into the global/prod registry" (an isolation **hard gate**).

**Result for the gate (Class-1 team-loop) graders:** ground-truth only (git metadata + committed files
+ bus files). **Zero** runner-*command* coupling in core grading — **with exactly one exception:**

> `cells/skill-inheritance/fixture/grade.sh` calls **`convoy ls`** (alongside `pty ls`) in its ISOLATION
> hard gate. **Decision (evals-owner, agreed with st2): keep `convoy ls` as-is** — no new st2 surface.
> On the st2 leg `leak_pty` (`pty ls`) is the *substantive* session-isolation gate, because st2 spawns
> every task through pty, so `pty ls` against the global pty root catches any st2 session leak (the pty
> layer is shared + unchanged; PTY_ROOT-honoring keeps `pty ls` identical). `leak_convoy` (`convoy ls`)
> stays a **prod-convoy-untouched** guard — real while the live fleet is still convoy, trivially-green
> but harmless on the st2 leg — and **retires at the swap** alongside convoy (st2 has no global registry;
> it's catalog-scoped). Same keep-during-transition/retire-at-swap policy as the Class-2 cells below.

Every other grader that calls the runner is a **Class-2 runner-subject** cell (the runner *is* its
subject — expected). Net: **bus-path + host-prefix is the only coupling for the gate core.** The lone
`convoy ls` isolation probe (skill-inheritance) stays as a prod-untouched guard, carried on st2 by
`pty ls`.

## 3. Class-2 (convoy-mechanism) disposition — recommendation (Nathan/CoS decision)

**Discriminator:** does the SWAP need this capability (→ **PORT** to an st2 sibling; part of "st2 works
for convoy's use cases") or does the cell grade convoy's OWN CLI/UX/self-test that st2 is not
reimplementing (→ **KEEP-as-convoy-regression** *or* **RETIRE**)?

| cell | subject under test | recommend | why |
| --- | --- | --- | --- |
| convoy-network | `convoy up` hosts a ding net + respawns | **PORT (P0)** | THE capstone — proves the runner hosts a network at all; highest-value gate port |
| crash-ding | `convoy up` crash-dings on hard worker death | **PORT** | st2 up must own respawn/crash detection |
| clean-compose | convoy add composes into a repo, zero pollution | **PORT** | directly exercises st2 render's overlay (the new surface) |
| compose-config-load | repo CLAUDE.md/skills load through compose (additive) | **PORT** | same — st2 render overlay must be additive |
| compose-global-skill | a global skill fires through compose, no-shadow | **PORT** | same — st2 render overlay must not shadow global scope |
| restorability | restore-without-resume via SessionStart hook | **PORT** | st2 must restore via its own hook |
| restorability-codex | ditto, codex parity | **PORT** | with codex rendering |
| convoy-init-structure | runner produces the network layout | **PORT** | foundational substrate every cell needs |
| convoy-worktree-cutting | runner cuts a real linked git worktree | **PORT (if st2 owns worktrees)** | else keep-as-convoy |
| convoy-doctor-canwork | `convoy doctor --full` self-test | **KEEP-or-RETIRE** | grades convoy's own end-to-end self-test — no st2 equivalent |
| convoy-doctor-structure | `convoy doctor` Structure narration | **KEEP-or-RETIRE** | convoy-specific narration |
| convoy-doctor-teardown | `convoy doctor` abort-reaps its org | **KEEP-or-RETIRE** | convoy-specific |
| convoy-doctor-foreign-box | `convoy doctor` foreign-box honesty | **KEEP-or-RETIRE** | convoy-specific probes |
| convoy-doctor-preinit | `convoy doctor` pre-init UX | **KEEP-or-RETIRE** | convoy-specific UX |
| convoy-init-narration | `convoy init` stdout narration/`--json`/`--quiet` | **KEEP-or-RETIRE** | convoy-specific UX |
| convoy-add-structure | `convoy add` overlay + git-exclude shape | **KEEP-or-RETIRE** (+ maybe an st2-render-structure sibling) | convoy-specific overlay shape |

**Fork RESOLVED by CoS:** **keep-during-transition, retire-at-swap.** The pure-convoy cells stay as
convoy-regressions while convoy still runs the live fleet (they have real value through the transition),
and retire *at* the swap when convoy is actually gone. So the KEEP-or-RETIRE column above reads
**keep-during-transition / retire-at-swap**. (CoS settles it firmly once Nathan is looped in on this
table.) The PORT set (capstone-first) is the high-value, gate-relevant slice everyone agrees on.

## 4. Boundaries

evals owns the harness + cells + graders; st2 owns the st2 runner. Neither writes to the other's repo;
cross-repo needs are routed. Handoff point: when st2's convoy-add-shaped surface (G5) is stable, wire
`stev_convoy_add` → it.
