# Orbit workspace launch specification

`firstCommandArgv` is the single shell-data decoding seam. Validation consumes
its returned argv and never searches the raw command string for policy text.
The validator now skips an optional `exec`, or `env` followed by assignment
words, before selecting an `orbit worker` subject.

For each selected task, the implementation walks options only until `--`,
collects short, split-long, and joined-long policy forms, requires exactly one,
and parses the value as JSON. The policy must contain one workspace entry whose
opaque key is byte-equal to the declaration and whose mode is `sandboxed`.

`buildWorkerTask` constructs that structured policy from the declared
workspace, serializes it once, and passes the serialized bytes through
`quoteShellWord`. Generated tasks therefore use the same validation path as
hand-authored catalog entries without executing command data.
