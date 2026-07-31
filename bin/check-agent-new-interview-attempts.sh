#!/usr/bin/env bash
# Validate pre-run evidence without representing it as a judged model run.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

ledger="evidence/agent-new-interview-attempts.tsv"
baseline=""
if [ "$#" -eq 2 ] && [ "$1" = "--baseline" ]; then
  baseline="$2"
elif [ "$#" -ne 0 ]; then
  echo "usage: $0 [--baseline COMMIT]" >&2
  exit 2
fi
expected_header=$'recorded_at_utc\tsource_commit\tst2_commit\tst2_sha256\taxe_source_commit\tadapter\truntime_profile\tstage\tresult\tdiagnostic\tcleanup'

[ -f "$ledger" ] && [ "$(head -n 1 "$ledger")" = "$expected_header" ] || {
  echo "FAIL: $ledger is missing or has an unexpected header" >&2
  exit 1
}

if [ -n "$baseline" ]; then
  bin/check-append-only-file.sh \
    --repo-root "$repo_root" --baseline "$baseline" --path "$ledger"
fi

rows=0
while IFS=$'\t' read -r recorded source st2_commit st2_sha axe_head adapter profile stage result diagnostic cleanup extra; do
  [ "$recorded" != "recorded_at_utc" ] || continue
  [ -n "$recorded" ] || continue
  [ -z "${extra:-}" ] || { echo "FAIL: $ledger row has extra columns" >&2; exit 1; }
  [[ "$recorded" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]] ||
    { echo "FAIL: invalid recorded_at_utc $recorded" >&2; exit 1; }
  [[ "$source" =~ ^[0-9a-f]{40}$ ]] && git cat-file -e "$source^{commit}" 2>/dev/null ||
    { echo "FAIL: unavailable source commit $source" >&2; exit 1; }
  [[ "$st2_commit" =~ ^[0-9a-f]{40}$ && "$st2_sha" =~ ^[0-9a-f]{64}$ ]] ||
    { echo "FAIL: st2 identity is not exact" >&2; exit 1; }
  [[ "$axe_head" =~ ^[0-9a-f]{40}$ && "$adapter" == /nix/store/* && "$profile" == /nix/store/* ]] ||
    { echo "FAIL: Axe/runtime artifact identity is not exact" >&2; exit 1; }
  [ "$stage" = "materialization" ] && [ "$result" = "PRE_AXE_FAIL" ] ||
    { echo "FAIL: pre-run evidence claims an unsupported stage or result" >&2; exit 1; }
  [ -n "$diagnostic" ] && [ "$cleanup" = "catalog-absent;process-absent" ] ||
    { echo "FAIL: pre-run evidence lacks diagnostic or cleanup proof" >&2; exit 1; }
  ((rows += 1))
done <"$ledger"

[ "$rows" -gt 0 ] || { echo "FAIL: $ledger has no evidence rows" >&2; exit 1; }
if [ -n "$baseline" ]; then
  printf 'PASS: %d pre-Axe attempt row(s) validated with exact artifacts, cleanup, and an immutable baseline\n' "$rows"
else
  printf 'PASS: %d pre-Axe attempt row(s) validated with exact artifacts and cleanup; no append-only baseline supplied\n' "$rows"
fi
