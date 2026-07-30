# Orbit workspace launch requirements

These requirements are protected during ordinary implementation.

- **ORB-R01 — subject.** Each active, workspace-backed `worker` task whose
  decoded first simple command launches `orbit worker` MUST carry exactly one
  launch policy argument. Inactive tasks, other task kinds, workspaceless tasks,
  and commands whose first executable is not Orbit worker are outside this
  requirement.
- **ORB-R02 — policy.** The policy argument MUST be valid JSON with exactly one
  `workspaces` entry. Its key MUST be byte-for-byte equal to the task's declared
  workspace and its value MUST be an object whose `mode` is `sandboxed`.
- **ORB-R03 — argv boundary.** Policy recognition MUST inspect decoded argv,
  accepting `-p VALUE`, `--policy VALUE`, and `--policy=VALUE`. Text inside
  another argument, after the argv `--` delimiter, or in a later shell command
  is not a policy argument. Optional leading `exec`, or `env` plus zero or more
  environment assignments, does not change the executable.
- **ORB-R04 — inert validation.** Catalog validation MUST treat commands as
  untrusted data. It MUST NOT execute a command, spawn a process, source a
  profile, or inspect a user or system account to decide validity.
- **ORB-R05 — generation.** The worker generator MUST emit a launch that
  round-trips the exact workspace bytes through JSON and shell decoding and
  satisfies the same validator used for hand-authored tasks.
