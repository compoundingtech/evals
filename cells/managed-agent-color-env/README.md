# managed-agent-color-env

**Type:** st2 / managed-agent environment policy · **Ship:** blocked on the st2 managed-agent color-default
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
- **Boundary:** ordinary non-agent PTYs retain their existing ambient-environment behavior. Standalone
  PTYs without an authored unset policy retain their existing ambient-environment behavior.
- **Cleanup:** the cell retires both declarations and proves its eval-owned PTY root is empty.

## Run it

```sh
st2 eval ./cells/managed-agent-color-env/
```

This cell is intentionally red until the managed-agent environment policy lands in st2.
