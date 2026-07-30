#!/usr/bin/env bash
# Validate append-only pre-run evidence without representing it as a judged model run.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

ledger="evidence/agent-new-interview-attempts.tsv"
expected_header=$'recorded_at_utc\tsource_commit\tst2_commit\tst2_sha256\taxe_feature_head\tadapter\truntime_profile\tstage\tresult\tdiagnostic\tcleanup'

[ -f "$ledger" ] && [ "$(head -n 1 "$ledger")" = "$expected_header" ] || {
  echo "FAIL: $ledger is missing or has an unexpected header" >&2
  exit 1
}

if git cat-file -e "HEAD:$ledger" 2>/dev/null; then
  prior="$(mktemp)"
  trap 'rm -f -- "$prior"' EXIT
  git show "HEAD:$ledger" >"$prior"
  prior_size="$(wc -c <"$prior")"
  current_size="$(wc -c <"$ledger")"
  [ "$current_size" -ge "$prior_size" ] && cmp -n "$prior_size" "$prior" "$ledger" || {
    echo "FAIL: $ledger rewrites or removes existing evidence; only append rows" >&2
    exit 1
  }
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
  [[ "$axe_head" =~ ^[0-9a-f]{7,40}$ && "$adapter" == /nix/store/* && "$profile" == /nix/store/* ]] ||
    { echo "FAIL: Axe/runtime artifact identity is not exact" >&2; exit 1; }
  [ "$stage" = "materialization" ] && [ "$result" = "PRE_AXE_FAIL" ] ||
    { echo "FAIL: pre-run evidence claims an unsupported stage or result" >&2; exit 1; }
  [ -n "$diagnostic" ] && [ "$cleanup" = "catalog-absent;process-absent" ] ||
    { echo "FAIL: pre-run evidence lacks diagnostic or cleanup proof" >&2; exit 1; }
  ((rows += 1))
done <"$ledger"

[ "$rows" -gt 0 ] || { echo "FAIL: $ledger has no evidence rows" >&2; exit 1; }
printf 'PASS: %d append-only pre-Axe attempt row(s) validated with exact artifacts and cleanup\n' "$rows"
