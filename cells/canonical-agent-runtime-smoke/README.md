# canonical-agent-runtime-smoke

This model-free cell exercises st2's production Agent Spec eval seam with one
deterministic shell agent. The canonical declaration is the sole launch and
routing authority: st2 boots it, delivers the kickoff to its native inbox,
requires a fresh reply, grades the root and routing receipts, and tears the PTY
down through normal eval cleanup.

It uses no Axe, account, model, or provider harness.

```sh
st2 eval ./cells/canonical-agent-runtime-smoke/
```
