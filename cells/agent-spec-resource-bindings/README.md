# agent-spec-resource-bindings

Model-free acceptance coverage for the native Agent Spec Resource envelope introduced by
[`compoundingtech/st2#86`](https://github.com/compoundingtech/st2/pull/86).

The cell proves the catalog contract directly through st2:

- KDL, TOML, and JSON reject malformed URIs, duplicate binding names, and unsupported policy properties.
- Resource names are unique, URI schemes remain open, and `_tag` is rejected as unsupported.
- Canonical KDL and supported TOML/JSON forms project the same stable, name-ordered
  `st2 agents --json` descriptors without normalizing URI bytes.
- Editing only Resource bindings updates the declared roster while the existing PTY keeps the same process
  identity and is adopted rather than stopped or relaunched.

It does not exercise folder-eval Resource projection, resolution, access, readiness, or Resource lifecycle
policy. Those are outside the portable envelope.
