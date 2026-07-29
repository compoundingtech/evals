#!/usr/bin/env bash
set -euo pipefail
test "$(cat "$CATALOG/results/foreign.code")" != 0
# The next Nix stage still succeeds from the pre-foreign expected ref, proving
# the rejected manager did not move it.
test "$(cat "$CATALOG/results/publish-b.code")" = 0
