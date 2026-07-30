#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"
source bin/st2-pin.sh

grep -Fq "$ST2_SOURCE_FULL" AGENT-SPEC.md
grep -Fq "$ST2_SOURCE_FULL" README.md
grep -Fq "$ST2_BINARY_SHA256" AGENT-SPEC.md
grep -Fq "$ST2_BINARY_SHA256" README.md
grep -Fq 'source bin/st2-pin.sh' bin/check-corpus.sh

if rg -n \
  '9887b28|d49d44fd4f3f6f655455c212353a469fefa956082bedf22163deb767d8a36a0d|0ec6a22|df0783843e5bb5b2bfd58323467b5ae0d89aebec4e12e5666139915e235ad2db' \
  AGENT-SPEC.md README.md bin/check-corpus.sh bin/st2-pin.sh; then
  echo "FAIL: active st2 pin surfaces retain the superseded source or binary hash" >&2
  exit 1
fi

echo "PASS: active spec, README, and executable preflight share st2 $ST2_SOURCE_FULL / $ST2_BINARY_SHA256"
