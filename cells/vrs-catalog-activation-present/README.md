# vrs-catalog-activation matched condition

This is one half of a blind, matched complex A/B. Both conditions contain the
same Harbor reconciler task, Claude Sonnet 5 medium seat, 1200-second timeout,
ordinary repository state, mutations, and eight executable judges. The only
treatment difference is the presence or absence of two architecture documents
under `docs/architecture/`.

The primary outcome is the executable architectural gate vector: durable
activation, last-known-good preservation, host partitioning, reachability
neutrality, crash atomicity, controller adoption, coupling, and
mutation-validity. Judges do not inspect citations or reward document prose.

`bin/check-vrs-complex.sh` verifies the treatment boundary, exact matched
surfaces, recorded hashes, planted good solution, and deliberately wrong
mutations without launching a model.
