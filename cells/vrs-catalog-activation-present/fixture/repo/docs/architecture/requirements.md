# Harbor host-local activation requirements

These requirements are protected during ordinary implementation.

- **HBR-R01 — local subject.** Reconciliation authority is one `(catalog,
  host)` subject. A host reads, activates, and converges only its own candidate,
  active receipt, and service registry. Remote declarations are never local
  desired state.
- **HBR-R02 — last complete state.** The last complete, validated, locally
  activated receipt remains authoritative when a candidate is missing,
  partial, malformed, invalid, or not newer. Such a candidate MUST NOT replace
  active state or cause running services to stop.
- **HBR-R03 — atomic activation.** A complete candidate MUST match the local
  host, contain a nonnegative integer version and unique string service names,
  and have a valid digest. A strictly newer candidate is staged as one complete
  receipt and atomically replaces the prior receipt. An interruption before
  replacement exposes the complete old receipt; a successful replacement
  exposes the complete new receipt.
- **HBR-R04 — independent progress.** Different hosts sharing synchronized
  catalog sources may temporarily activate different versions. Each progresses
  independently when it has a complete valid newer local candidate. Peer or
  source absence is factual, not a fleet-wide health failure.
- **HBR-R05 — explicit dependency.** Peer reachability affects local health or
  blocks activation only when the current local operation declares an explicit
  peer dependency. Even then, the active receipt and its running services
  remain intact.
- **HBR-R06 — controller replacement.** Replacing the local control process
  MUST adopt unchanged services by preserving their instance identities and
  updating controller ownership. Only a local desired-state removal stops a
  service; only a local desired-state addition starts one.
- **HBR-R07 — inert model.** The package models persistence and service
  identity with repository-local data. It MUST NOT launch processes, inspect
  machine accounts, introduce a global active pointer, or write another host's
  active receipt or registry.
