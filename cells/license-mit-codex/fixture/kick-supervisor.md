<!-- HERMETIC KICK for the license-mit CODEX cell. The ONLY input to the team. spin.sh strips this HTML
header and seeds the message into lmc-sup's coord inbox with a boot-time ms filename so the boot ritual
ACTS on it (not archive-as-stale). `from:` is a synthetic requester so the loop is observable + reproducible.
Kept minimal + identical in intent to the matrix `license-mit` run so the Codex cell is directly comparable. -->
---
from: eval-runner
subject: "the widget library's license should be MIT"
priority: high
---
The `widget` library's license should be **MIT**. Right now it ships a proprietary / all-rights-reserved
license — please get it changed to the standard MIT license across the repo (the `LICENSE` file and any
license metadata), keep it minimal and correct, and keep the repo committed + clean.

You're the supervisor: your specialist `lmc-worker` owns that repo — delegate the change to it, verify
read-only when it reports done, and reply to me (`eval-runner`) with the commit + your verification.
Stay in lanes: `lmc-worker` touches only its own repo; everything else is coordinated by coord message.
