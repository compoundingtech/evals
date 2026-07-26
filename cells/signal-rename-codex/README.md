# signal-rename-codex — coordinated cross-package rename

Codex-native twin of [`signal-rename`](../signal-rename/). A supervisor and three package owners rename
the product `signal` to `beacon` across a base package, two consumers, and configuration while preserving
the unrelated `AbortSignal` / `controller.signal` / `SIGTERM` runtime primitive.

What it teaches:

- decomposition: each specialist commits only its owned package lane;
- sequencing: the base rename lands before consumers adopt the new package and protocol;
- judgment: product references change, runtime primitives do not;
- integration: the supervisor closes the temporary alias window and verifies the assembled graph.

Run it:

```sh
st2 eval ./cells/signal-rename-codex/
```

The fixture is deterministic. `fixture/materialize.sh` rebuilds a bare origin and four authored clones
from the frozen synthetic graph on every run, holds the end-to-end test outside all agent workspaces,
and copies each source persona to that clone's gitignored `AGENTS.md`. Codex loads those files directly.
The KDL uses native bare `ding`; it authors no bus path or compatibility wake command.

Five held-out judges grade the integrated `sig.sup` clone: per-author path isolation, every package suite
green, complete product rename, primitive preservation, and an end-to-end driver that resolves the renamed
base/relay/hub stack.

Run provenance and current pass evidence live in [`../../HARNESS-MATRIX.md`](../../HARNESS-MATRIX.md).
