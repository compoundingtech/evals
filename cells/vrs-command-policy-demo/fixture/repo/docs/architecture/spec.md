# Orbit workspace launch specification

`firstCommandArgv` is the single shell-data decoding seam. Validation consumes
its returned argv and never searches the raw command string for policy text.
After skipping an optional `exec`, or `env` followed by assignment words, the
subject selector compares the first two executable words with `orbit worker`.

For a subject task, validation walks options only until `--`. It collects policy
occurrences in their supported short, split-long, and joined-long forms,
requires exactly one, parses the value as JSON, and validates the complete
structured shape from ORB-R02. Workspace strings remain opaque bytes; path
normalization, resolution, case folding, and filesystem lookup are forbidden.

`buildWorkerTask` constructs the policy object from the declared workspace,
serializes it once, and shell-quotes the serialized value with
`quoteShellWord`. The resulting task must pass `validateCatalog`.
