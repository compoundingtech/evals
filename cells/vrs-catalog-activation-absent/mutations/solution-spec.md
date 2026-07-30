# Harbor host-local activation specification

The implemented store validates complete candidate envelopes, exact host,
integer version, unique service names, and digest before comparing a candidate
with `active/<host>/receipt.json`. A newer receipt is written to a sibling
staging file and atomically renamed. Missing or invalid candidates return the
previous complete receipt, and the fault-injection seam leaves that receipt
unchanged.

The reconciler treats ordinary peer loss as neutral and continues from local
staged input. Only an explicit dependency blocks activation; either path
converges the active local receipt. Runtime state is kept per host. A
replacement controller adopts unchanged names without replacing their instance
identities, while starts and stops follow only local desired-state additions
and removals.
