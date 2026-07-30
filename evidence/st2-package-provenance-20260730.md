# st2 package-provenance observation — 2026-07-30

The corpus pins source commit
`c6846f6239329f0803142afc06c15a07b93937c1`, but a source commit and reported
version do not identify a debug executable. Two clean debug builds from two
different st2 checkouts at that commit reported the same
`st2 0.1.0 — running from local source (c6846f6, ...)` version and produced
different bytes:

| Checkout binary | SHA256 |
|---|---|
| `/tmp/st2-pr56-pin-c6846f6/target/debug/st2` | `43eedd7aba6fa886163dac0ff2130f901b940507aa9c787b913300aadebdee56` |
| `/tmp/st2-pr56-pin-c6846f6-second/target/debug/st2` | `dc9661839d0f6e168c95fb92ac50832d4c9a0745cbd979b7ba0d72993fce9a59` |

Each executable contained its distinct checkout path in its string table. These
temporary paths and hashes are empirical evidence only, not corpus inputs.
They demonstrate why a checkout-built executable hash is not a portable runner
identity.

The accepted runner is instead the immutable Nix output
`/nix/store/z4wj1y20wq00n02gpknnz45fdi2kyc7h-st2-0.1.0`, tied to the exact
source-store `flake.lock`, derivation, NAR hash and size, packaged version
prefix, and executable hash recorded in `bin/st2-pin.sh`.
`bin/check-st2-package-provenance-mutations.sh` keeps the distinction
non-vacuous without rebuilding either debug checkout: the exact packaged
binary passes, while a different executable reporting the same packaged
version is rejected.
