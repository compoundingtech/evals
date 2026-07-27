# two-networks-coexist — catalog and pty isolation

This deterministic, model-free cell runs two independent native st2 catalogs concurrently. Each catalog has its
own flat message root and `PTY_ROOT`.

The positive controls require a live ACK-reader session and one delivered message in each catalog. Held-out
judges then prove:

- catalog A cannot enumerate catalog B's pty session, and vice versa;
- catalog A contains only its own message payload, and vice versa; and
- both isolated sessions are explicitly stopped after the probes.

It uses the current `--catalog` surface throughout; it does not author a compatibility bus directory or legacy
root override.

Run it with:

```sh
st2 eval ./cells/two-networks-coexist/
```
