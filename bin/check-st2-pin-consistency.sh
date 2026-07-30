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
grep -Fqx "source_full	$ST2_SOURCE_FULL" cells/catalog-plan-vs-direct-brief/fixture/runner.tsv
grep -Fqx "source_short	$ST2_SOURCE_SHORT" cells/catalog-plan-vs-direct-brief/fixture/runner.tsv
grep -Fqx "binary_sha256	$ST2_BINARY_SHA256" cells/catalog-plan-vs-direct-brief/fixture/runner.tsv

if rg -n \
  '9887b28|c6846f6239329f0803142afc06c15a07b93937c1|d49d44fd4f3f6f655455c212353a469fefa956082bedf22163deb767d8a36a0d|2bba8d58be24250bc262f75f835ce2d780369add275774f3f2135c623d23d29c' \
  AGENT-SPEC.md README.md bin/check-corpus.sh bin/st2-pin.sh; then
  echo "FAIL: active st2 pin surfaces retain a superseded source or binary hash" >&2
  exit 1
fi

echo "PASS: active spec, README, and executable preflight share st2 $ST2_SOURCE_FULL / $ST2_BINARY_SHA256"
