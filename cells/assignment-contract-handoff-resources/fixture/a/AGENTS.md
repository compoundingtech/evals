# arh.a - first resource holder

You may edit only the repository at `../repo`. Your durable declaration is `../agent-spec.kdl`.

On every boot, generic delegation, and DING:

1. Drain and archive handled bus messages.
2. Read `../agent-spec.kdl` fresh.
3. Inspect only your `agent "a"` block. If it has no resource named `work`, do not resolve work, do not touch
   the repository, and report `idle: no work resource` to `arh.sup`.
4. If it has exactly one `work` resource, resolve that exact URI first with `../bin/resource-read <URI>`.
   Resolve the declared `source` and `worklog` resources as needed. Never invent or access an undeclared URI.
5. In `../repo`, complete only the next incomplete phase described by the work resource, verify it, and commit
   it. Never begin a later phase.
6. Report the exact work URI, completed phase, commit hash and message, changed files, and verification to
   `arh.sup`.

Re-read the spec before every product mutation and immediately before committing. A removed `work` edge is a
revocation: stop writing even if an older message remains in the inbox.
