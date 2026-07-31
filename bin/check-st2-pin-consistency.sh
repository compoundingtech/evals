#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"
source bin/st2-pin.sh

grep -Fq "$ST2_SOURCE_FULL" AGENT-SPEC.md
grep -Fq "$ST2_SOURCE_FULL" README.md
grep -Fq "$ST2_FLAKE_LOCK_SHA256" AGENT-SPEC.md
grep -Fq "$ST2_DERIVATION" AGENT-SPEC.md
grep -Fq "$ST2_OUTPUT_PATH" AGENT-SPEC.md
grep -Fq "$ST2_OUTPUT_NAR_HASH" AGENT-SPEC.md
grep -Fq "$ST2_VERSION_PREFIX" AGENT-SPEC.md
grep -Fq "$ST2_BINARY_SHA256" AGENT-SPEC.md
grep -Fq "$ST2_FLAKE_LOCK_SHA256" README.md
grep -Fq "$ST2_OUTPUT_PATH" README.md
grep -Fq "$ST2_OUTPUT_NAR_HASH" README.md
grep -Fq "$ST2_BINARY_SHA256" README.md
grep -Fq 'source bin/st2-pin.sh' bin/check-corpus.sh
grep -Fq 'bin/check-st2-package-provenance.sh' bin/check-corpus.sh
grep -Fq 'bin/check-st2-package-provenance-mutations.sh' bin/check-corpus.sh

if rg -n \
  '9887b28|d49d44fd4f3f6f655455c212353a469fefa956082bedf22163deb767d8a36a0d|0ec6a22|df0783843e5bb5b2bfd58323467b5ae0d89aebec4e12e5666139915e235ad2db|2bba8d58be24250bc262f75f835ce2d780369add275774f3f2135c623d23d29c' \
  AGENT-SPEC.md README.md bin/check-corpus.sh bin/st2-pin.sh; then
  echo "FAIL: active st2 pin surfaces retain the superseded source or binary hash" >&2
  exit 1
fi

echo "PASS: active spec, README, and executable preflight share exact packaged st2 $ST2_SOURCE_FULL / $ST2_OUTPUT_NAR_HASH"
