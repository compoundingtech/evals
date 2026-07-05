<!--
HERMETIC KICK for the tui-build cell. This is the ONLY input to the team — no live agent prompts anyone.
spin.sh strips this HTML header and materializes the rest into tui-sup's inbox as a valid coord filename
(<13-digit-ms>-<6alnum>.md) with a boot-time ms so the boot ritual ACTS on it. `from: river` is the
synthetic principal (reproducible, not a live sender).
-->
---
from: river
subject: "build us the agent-network TUI — two views + a real usability pass"
priority: high
---
I want to be able to *see* the agent network at a glance in the terminal — who's around, their status,
who has unread messages, and a preview of the latest message when I select someone.

Build it as a small TUI in the repo you own, in **two layouts that share one data layer**:

  1. a **tree** view with a preview pane — agents as a navigable tree; selecting one previews it;
  2. a **cards** view with a preview pane — the same data as cards; selecting one previews it.

It reads the network **read-only** — the agent list from `coord agents --enrich --json` and the message
dir under `$ST_ROOT` — and must **never** write agent state. There are prototype views already (a
tree+preview and a cards+preview), built on `@myobie/pty/tui` — start from those, don't restart from scratch.

Then — the part I actually care about — do a **real usability pass**: put fresh eyes on it and find the
human-centered problems (empty states, long/overflowing lists, truncation, statuses that don't read
clearly, "how do I even navigate this"), and **fix what you find**. Making it render is table stakes;
catching that it's awkward to use and fixing it is the point.

Keep it green — write and run tests for the data layer and the views (use the frozen fixture, not the live
network). When you're done, tell me how you split the work across the team, what usability problems you
found, and what you changed because of them.

Stay in your lanes: each of you touches only the module you own; coordinate everything else by message.
