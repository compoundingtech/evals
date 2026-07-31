# managed-agent-color-env

**Type:** st2 / managed-agent environment policy · **Ship:** blocked on the st2 managed-agent color-default
change.

**Capabilities required:** `st2,pty,jq`. No model and no bus. The cell reconciles two synthetic managed agents
under an ambient `NO_COLOR=1`: one leaves the key undeclared and one explicitly declares `NO_COLOR "1"`.

## What it proves

- **Color-capable default:** the canonical `agent` PTY does not inherit an ambient `NO_COLOR` from the st2
  reconciler and still receives `TERM=xterm-256color`.
- **Authored override:** an explicit Agent Spec `env { NO_COLOR "1" }` remains present. This is the negative
  control that prevents a blanket environment deletion from passing.
- **Live adoption:** a second reconciliation adopts both live PTYs without creating another generation.
- **st2-owned replacement:** after both PTYs are killed, reconciliation creates new generations with the same
  default-vs-explicit distinction. The observation is made inside the task, after any transient systemd scope
  wrapper, rather than by inspecting launch arguments.
- **Boundary:** ordinary non-agent PTYs retain their existing ambient-environment behavior. Standalone
  `pty restart` is intentionally outside this cell: st2 owns the negative overlay at reconciliation time,
  while positive authored values are persisted by PTY.
- **Cleanup:** the cell retires both declarations and proves its eval-owned PTY root is empty.

## Run it

```sh
st2 eval ./cells/managed-agent-color-env/
```

This cell is intentionally red until the managed-agent environment policy lands in st2.
