# managed-agent-color-env

**Type:** st2 / managed-agent environment policy · **Ship:** depends on the st2 managed-agent color-default
change.

**Capabilities required:** `st2,pty,jq,systemd-user`. No model and no bus. The cell reconciles two synthetic
managed agents under an ambient `NO_COLOR=1`: one leaves the key undeclared and one explicitly declares
`NO_COLOR "1"`.

## What it proves

- **Color-capable default:** the canonical `agent` PTY does not inherit an ambient `NO_COLOR` from the st2
  reconciler and still receives `TERM=xterm-256color`.
- **Authored override:** an explicit Agent Spec `env { NO_COLOR "1" }` remains present. This is the negative
  control that prevents a blanket environment deletion from passing.
- **Real isolation wrapper:** both tasks must run in their own st2 transient user scopes. A missing user manager
  is a hard failure, so the direct-spawn fallback cannot make the environment assertion pass accidentally.
- **Live adoption:** a second reconciliation adopts both live PTYs without creating another generation.
- **st2-owned replacement:** after both PTYs are killed, reconciliation creates new generations with the same
  default-vs-explicit distinction. The observation is made inside the task, after any transient systemd scope
  wrapper, rather than by inspecting launch arguments. The replacement generations must also run in fresh
  scopes.
- **standalone PTY restart:** the default agent is restarted by `pty restart` while the operator environment
  contains `NO_COLOR=1`; its persisted unset policy must still win. The explicit agent is restarted without an
  ambient value and must retain its authored `NO_COLOR=1`. This proves both precedence directions from stored
  metadata rather than relying on st2 to reconstruct the command.
- **Dependency ownership:** the accepted `0fed14b` st2 with the current PTY exposes ambient `NO_COLOR` on the
  initial launch, while the current st2 with a deterministic PTY mutation that strips `--unset-env` passes the
  initial observation but reintroduces `NO_COLOR` on restart. These controls isolate launch policy from restart
  persistence without representing the wrapper mutation as a released PTY artifact.
- **Boundary:** ordinary non-agent PTYs retain their existing ambient-environment behavior. Standalone
  PTYs without an authored unset policy retain their existing ambient-environment behavior.
- **Cleanup:** the cell retires both declarations, proves its eval-owned PTY root is empty, verifies every
  observed process identity has ended, and rejects active st2 transient scopes or the exact scope cgroup paths
  captured while those reconciled generations were live.

## Run it

```sh
EVAL_OLD_ST2=/path/to/st2-0fed14b st2 eval ./cells/managed-agent-color-env/
```

The current st2 executable and the `EVAL_OLD_ST2` control are checked by source version and SHA-256; the
current PTY executable is checked by SHA-256 because its version output does not carry a source revision. These
checks run before either run step starts. The control is the Linux executable from the immutable
[`v0.2.0+0fed14b`](https://github.com/compoundingtech/st2/releases/tag/v0.2.0%2B0fed14b) release.

## Accepted dependency receipt

The composed runtime uses:

- PTY `d5fabc3917407aeb937a012bd97679c303e18033` (merged);
- st2 `ffdb83c9541978a96ff8ce4c466628e15918cbc1`, the exact stream candidate proven by this corpus.

The executable SHA-256 identities are:

- PTY: `1c9716d435ca56ad9b4f67056d76fa6856cdc08e6bbda1fd4be6f59952e9fde3`;
- st2 candidate source: `adbd2099db237c17df3dac29052cb387f4ed99888e7477910c33e518c377a3e8`;
- st2 `0fed14b` control: `d61d12b2b1189a391c196ca28f8f4ba69072d14fcbad2571fc29db1f250f4eed`.

The exact st2 candidate identity is the accepted composition boundary for this cell and the repository-wide
corpus runner.
