# stream-nix-build-waiter

Model-free use-case E2E for waiting on real Nix builds through native st2 stream adapters.

Two adapters are lowered from Agent Spec and supervised by st2. Each creates a uniquely named local
`runCommand` derivation so the build cannot be satisfied by an earlier eval. The builders remain active for
two seconds, making the pre-terminal waiting state observable. One build succeeds and one exits with status
23; both outcomes are converted into truthful terminal events through the public `st2 event emit` CLI.

Each waiter repeats the identical terminal publication to model retry after an uncertain acknowledgement.
Before that succeeds, a fixture wrapper injects two transient failures at the real `st2 event emit` process
boundary. The adapter retries the exact immutable arguments with a bounded exponential schedule and remains
supervised rather than flapping. The wrapper then forwards to the explicitly captured candidate st2 binary;
Nix itself is never mocked.

The cell then kills and reconciles both adapters, proving a fresh process derives the same event identity from
the stable build request and is also deduplicated. It retains the original filename and leaves exactly one
inbox message per build. Finally it shuts the agent down and proves no waiter task or eval-owned PTY remains.

The fixture is hermetic with respect to external services: it uses the host's configured `<nixpkgs>` but no
network, credentials, substituter fetch, or model seat. The expected-failure derivation is an intentional
negative control, not an infrastructure error.
