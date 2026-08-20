# stream-github-ci-waiter

Use-case E2E for waiting on GitHub PR checks and delivering the terminal result through an st2 stream.

The maintained model-free lane deterministically exercises two pending polls followed by success, stable replay
deduplication, terminal failure superseding success for the same PR key, bounded timeout with no event, and
cleanup. It uses the same `gh` JSON boundary as the live lane.

The authenticated smoke lane waits through a real pending-to-terminal Nix transition on the immutable merged
[`compoundingtech/st2#285`](https://github.com/compoundingtech/st2/pull/285), verifies its exact head, records
every observed check state, and emits the result through `st2 event emit`. Rerun the existing successful workflow
immediately before starting it. It is opt-in because the maintained corpus must remain runnable offline and must
not make public GitHub state a flaky merge gate:

```sh
STREAM_GH_LIVE=1 st2 eval ./cells/stream-github-ci-waiter/ --keep
```

The smoke test is read-only. It requires an authenticated `gh` session with repository read access and never
reruns, cancels, edits, comments on, or otherwise mutates the PR or its checks.
