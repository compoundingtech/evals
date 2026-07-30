# cross-pty-root-admission

Model-free regression coverage for a catalog changing its effective PTY root while a declared task survives.
The fixture is synthetic and uses only eval-owned catalogs, state directories, workspaces, and PTY roots.

The same-root control requires ordinary reconciliation to adopt the existing task with the same PID. Two
transition cases then exercise root A to root B and root B to root A. A conforming implementation may adopt the
survivor across roots, explicitly migrate it, or fail closed while preserving it. In every case, the hard
property is exactly one live task with the stable identity after reconciliation.

Two positive controls constrain a fail-closed implementation: after the old exact task exits, reconciliation
must advance to the declared root; and a live sibling-prefix PTY in the previous root must not be mistaken for
the exact declared task.

Current st2 `main` at `33d159be90f43eac557ca2b86056ea288e569320` is expected to fail both directional
transition judges and their aggregate survival judge: it sees only the newly effective root and launches a
second process with the same identity. This cell therefore remains a truthful red characterization until the
product fix lands; it is not accepted PASS evidence.

Upstream tracking and the standalone immutable reproduction:

- <https://github.com/compoundingtech/st2/issues/75>
- <https://github.com/schickling-repros/2026-07-st2-cross-pty-root-duplicate/tree/9976c9fdd723f6ccd99ecb9330e6016be1a12ae4>

Run after an explicit eval authorization:

```sh
st2 eval ./cells/cross-pty-root-admission/
```
