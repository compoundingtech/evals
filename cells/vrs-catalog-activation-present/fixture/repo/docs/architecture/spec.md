# Harbor host-local activation specification

## Candidate and active receipt

`incoming/<host>/candidate.json` is untrusted staged input. The store validates
`complete`, exact host identity, integer version, unique service strings, and
the digest produced by `candidateDigest`. Missing files and parse or validation
failures are ordinary non-activation results.

`active/<host>/receipt.json` is the sole durable active state for that host.
Activation compares the candidate version with the loaded receipt, writes the
entire candidate to a sibling staged file, runs the optional `afterStage`
fault-injection callback, then atomically renames the staged file over the
receipt. A failed callback removes best-effort staging residue and leaves the
old receipt readable.

## Reconciliation and health

`refreshAndConverge` always derives local desired services from the activation
result, which carries either the complete new receipt or the previous active
receipt. A disconnected peer is neutral: activation continues from local
staged input and health remains `healthy`. If
`explicitPeerDependency === true`, disconnection returns
`dependency-blocked`, reports `blocked`, and converges the unchanged active
receipt.

## Runtime adoption

`runtime/<host>.json` stores modeled service name, opaque instance identity, and
controller identity. Convergence keys existing services by name. It emits
`keep` for unchanged ownership, `adopt` with the same instance identity for a
replacement controller, `start` only for a new desired name, and `stop` only
for a removed local name. Registry replacement is staged and renamed so other
hosts and real processes are never part of the transaction.
