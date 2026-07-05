# tui-build — usability find→fix rubric (HELD-OUT grade)

The team never sees this. It makes the partly-subjective usability discriminator **reproducible**: a
grader (a human, or a cross-family judge — a Claude judge inflates Claude work, so prefer Codex/GLM) scores
the team's usability pass against the problems the frozen fixture **deliberately plants**. Score each as
**found? → fixed? → verified?** — the discriminator is FIXING, not just listing.

## The fixture plants these (via `generate-fixture.sh`), in priority order

1. **Unmodeled statuses (the headline).** The seed's mock type + `statusColor` model only
   `available | unknown | offline`. The real/frozen network returns **`away` (lyra), `busy` (nova),
   `dnd` (vega)** too. A view that ships the seed's 3-way `statusColor` will **mis-color or drop** these.
   - *Expected find:* "the real network has statuses the view doesn't handle (away/busy/dnd) — they render
     wrong / like offline / uncolored."
   - *Expected fix:* extend the status handling (color + legible label) to cover them; don't crash or
     silently coerce. **HIGH weight** — this is the core "it renders the mock but not the real network" trap.

2. **Overflow inbox / badge legibility (orion = 12).** Does the unread badge stay legible, and does the
   list/preview truncate gracefully rather than overflow the pane?  *MED weight.*

3. **Empty states (nova / vega / echo = 0 inbox).** Is "no unread" clearly *nothing* (not a confusing
   `📬0` / blank that reads as broken)?  *MED weight.*

4. **Cold-readability of the preview (also the held-out cold-nav check).** Can a cold user, from the built
   view alone, tell **who's around, who has unread, and read the selected agent's latest message**? The
   preview pane must actually show the selected agent's latest message legibly.  *HIGH weight.*

5. **Degraded / stale state (zephyr → `unknown` via stale mtime).** Is a stale/unknown agent distinguishable
   from an active one (not shown as confidently "here")?  *LOW–MED weight.*

6. **Navigation discoverability.** Is it clear how to move + select (some affordance / hint), or is it
   "how do I even use this"?  *LOW–MED weight.*

## Scoring

- **PASS (strong):** finds + FIXES #1 and #4 (the two HIGH), plus ≥2 of #2/#3/#5/#6, each fix verified
  (re-rendered against the frozen fixture). Findings are specific + prioritized (real blockers over nitpicks).
- **PASS (adequate):** #1 and #4 found + fixed; the rest at least surfaced.
- **FAIL:** #1 (unmodeled statuses) or #4 (cold-readability) missed OR merely listed-not-fixed — "renders
  the mock, unusable on the real network" is exactly what this cell catches.

## Notes for the grader

- **Emergent finds are a bonus, not required.** (E.g. a prior run caught a wide-emoji `📬`/`📭` glyph that
  corrupts under incremental re-render and narrowed it to a width-1 glyph — a real bug the fixture didn't
  plant. Credit such catches.)
- Grade the **loop**, not just the list: a finding routed to the module owner, fixed in-lane, and
  re-reviewed by `tui-ux` is worth more than a long unactioned list.
- Read `tui-ux`'s findings messages on the bus + the resulting commits together; the fix commits should be
  authored by the **view owner** (tui-tree / tui-cards), never by tui-ux (isolation).
