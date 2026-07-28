# bootstrap-network — a directory that never existed is already a working bus

**Discriminates:** is there **any** step between a newcomer and a delivered message? This grades the claim that
there is none: the target root does **not exist** when the run starts, one `st2 message send --catalog <root>`
creates it, and send/read/reply/archive then all work on it with **neither identity registered anywhere**.
(deterministic, held-out)

**Capabilities required:** `st2`. No LLM, no pty, no bus fixture — nothing is copied in, because having
something to copy in is the thing being ruled out.

Contrast with the neighbours: `st2-network` grades whether **`st2 up` hosts a declared net**, and its README
parks the newcomer's zero-to-network path on the grounds that there is no init or onboarding command.
`two-networks-coexist` grades **partition** between two roots, and pre-creates both before using them. Neither
asserts that a root nobody made is usable, which is what makes the missing init command a design property
rather than a gap.

## What it proves

- **Zero init:** the step before first contact asserts the root is **absent** — so the send is provably the
  thing that created it, and no earlier step can have quietly bootstrapped anything.
- **The whole verb surface, on that root:** the message lands in the recipient's inbox (`ls`), reads back with
  its body and its sender (`read`), is answered **in-reply-to** the original rather than as a fresh send
  (`reply`), and archives out of the inbox (`archive` → `inbox=0 archive=1`).
- **Attribution without registration:** `bn-setup` and `bn-probe` are named for the first time by the commands
  that use them. Nothing declares them; the `from:` on both directions still resolves.
- **Control — the newcomer root really was the target:** the eval's own default bus (`$CATALOG`) must stay
  empty. Every step names `--catalog` explicitly, and the ambient fallback root is a working bus too, so a
  build that ignored `--catalog` would otherwise pass every judge above on the wrong root.

## Mutation evidence

Three deliberately wrong variants were run; each fails exactly the judges it should:

| Mutation | Result |
|---|---|
| first contact drops `--catalog` (writes to the ambient bus) | `DELIVERED`, `READABLE`, `THREADED REPLY`, `ARCHIVE`, `CONTROL` fail |
| the reply is a fresh `send` instead of `reply` | only `THREADED REPLY` fails |
| the root is created before first contact (an init step exists) | only `ZERO INIT` fails |

## Run it

```sh
st2 eval ./cells/bootstrap-network/
```
