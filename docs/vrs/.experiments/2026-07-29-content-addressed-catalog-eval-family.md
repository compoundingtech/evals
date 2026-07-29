# Content-addressed catalog eval family

## Question

Can the existing model-free folder-eval contract express sharp, portable
outcomes for immutable Agent Spec preparation and atomic catalog admission
without changing the eval runner or assigning runtime policy to evals?

## Method

The exploration used:

- `compoundingtech/evals`
  `78210568e47244d80de99c18d0eea2d6b641c18a`;
- `compoundingtech/st2`
  `6f1fe484b517406b80d06f335997859b1a53f609` for initial RED exploration;
- st2 prototype
  `16ee7eb953508801a4603edd056ab32f28986601` for retained-cell validation; and
- ordinary team-less folder evals with deterministic run steps and held-out
  shell or typed JSON judges.

The exploration designed five cells that divide the publication boundary into
independently falsifiable outcomes:

1. `agent-spec-lifecycle-catalog-prepare`;
2. `agent-spec-lifecycle-catalog-publish-cas`;
3. `agent-spec-lifecycle-catalog-root-atomicity`;
4. `agent-spec-lifecycle-catalog-root-resource-admission`; and
5. `agent-spec-lifecycle-catalog-crash-barriers`.

The maintained first slice retains only prepare/import, staged ref publication,
and catalog-root admission:

1. `agent-spec-lifecycle-catalog-prepare`;
2. `agent-spec-lifecycle-catalog-publish-cas`; and
3. `agent-spec-lifecycle-catalog-root-atomicity`.

Typed resource admission and public crash-boundary injection remain future
discriminators. The prototype also intentionally excluded resident runtime
generation and replacement. Those outcomes belong in later cells only when the
corresponding st2 implementation exists.

A reference publisher model exercised deterministic content identity, immutable
object-first publication, ref CAS, and durable-boundary crashes. Four reference
cells passed with scores `7/0`, `4/0`, `7/0`, and `4/0`. Mutations for a wrong
digest, corrupt object, absent CAS, and ref-before-object failed the intended
judges with scores `6/1`, `2/2`, `5/2`, and `1/3`.

Separate executable state models tested root-level semantics:

- independent per-seat pointers admit a catalog-invalid union, while one root
  CAS plus whole-catalog validation rejects it;
- object-only expectations admit ABA, while immutable parent-root expectations
  reject it; and
- asynchronous resource binding admits a desired revision before its required
  binding, while one admission-root transition exposes only complete old or new
  states and preserves stable identity-owned resource bytes.

Early product-conformance drafts were run directly against st2 rather than the
reference shim. They began as honest RED scenarios while st2 lacked a catalog
API. Once the first concrete CLI slice existed, the retained cells were lowered
to `catalog prepare`, `catalog stage`, `catalog admit`, `catalog head`, and
`catalog inspect`. All retained judges pass locally against st2 prototype
`16ee7eb953508801a4603edd056ab32f28986601`; that is implementation feedback,
not yet accepted corpus-pin evidence.

The concrete st2 CLI is being incubated in
[`compoundingtech/st2#52`](https://github.com/compoundingtech/st2/issues/52).
Command lowering in these cells must follow that implementation rather than
freeze speculative verbs.

## Result

The existing eval runner is sufficient. No custom parser, lifecycle hook,
daemon, model, or paid judge is required.

The three retained E2E cells prove these portable outcomes against the local
st2 prototype:

- preparation imports exact Agent Spec bytes idempotently without
  changing the selected catalog root;
- staging uses a parent ref identity, manager fence, and replay key without
  changing catalog visibility;
- the catalog root, not independent seat pointers, is the atomic desired-state
  boundary;
- each seat ref retains its manager ownership while a root transaction records
  its actor rather than taking global custody of every admitted seat;
- a multi-seat admission crosses one root CAS without exposing a mixed
  snapshot; and
- digest corruption of an admitted object fails closed during inspection.

The separate reference models suggest two additional directions but the
retained E2E family does not claim to prove them: typed resource compatibility
and interruption behavior at durable publication boundaries. They remain
future discriminators pending real public st2 surfaces.

The three-cell first slice remains proposed, not accepted evidence. Its command
scripts target the concrete #52 prototype and pass locally, including
mixed-manager preservation and corruption rejection. It becomes maintained
evidence only after every judge has mutation evidence and all three cells pass
against an st2 commit pinned by this repository.

The typed resource-admission and crash-barrier prototypes remain recorded here
but are deliberately absent from the maintained corpus until st2 exposes a real
typed binding contract and a stable black-box crash oracle.

## VRS Impact

- Suggests extending the spec-extraction section with catalog publication as a
  three-cell model-free, portable outcome family.
- Does not change `vision.md`, `requirements.md`, or `AGENT-SPEC.md`.
- Leaves storage layout, digest encoding, CLI spelling, locking, fsync,
  failpoint names, and recovery machinery owned by st2.
- Leaves manager selection, Nix lowering, authorization, and deployment
  acceptance owned by consumers such as dotfiles.
