#!/usr/bin/env bash
# Prove the free preflight can reach only static/parser/fs/git work and known offline materializers.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

reachable=(
  bin/check-corpus.sh
  bin/check-append-only-file.sh
  bin/check-agent-new-interview-attempts-mutations.sh
  bin/check-agent-new-renderer-security.sh
  bin/check-agent-new-interview-attempts.sh
  bin/check-canonical-agent-template-mutations.sh
  bin/check-canonical-agent-template.sh
  bin/check-event-first.sh
  bin/check-fixture-reset.sh
  bin/check-fixture-reset-terminal.sh
  bin/check-harness-contract.sh
  bin/check-kdl-parse.sh
  bin/check-model-policy-mutations.sh
  bin/check-model-policy.sh
  bin/check-no-pii-history.sh
  bin/check-no-pii.sh
  bin/check-overnight-policy.sh
  bin/check-preflight-safety.sh
  bin/check-run-history.sh
  bin/check-retired-surfaces.sh
  bin/check-st2-pin-consistency.sh
  bin/check-st2-semantic.sh
  bin/check-vrs-scope-drift.sh
  bin/check-vrs-variations.sh
  bin/check-weird-git-setup.sh
  bin/corpus-inventory.sh
  bin/generate-catalog.sh
  bin/model-agent-inventory.sh
  bin/st2-pin.sh
)
materializers=(
  cells/agent-new-interview/fixture/prepare-interviewer-worktree.sh
  cells/agent-new-bundle-contract/fixture/render-intent.sh
  cells/agent-new-interview/fixture/interviewer/render-intent.sh
  cells/canonical-agent-runtime-smoke/fixture/prepare-interviewer-worktree.sh
  cells/signal-rename/fixture/materialize.sh
  cells/signal-rename-codex/fixture/materialize.sh
  cells/weird-git-setup/fixture/setup-megarepo.sh
)
dry_run_only=(
  bin/overnight.sh
)

failed=0
fail() {
  printf 'FAIL: %s\n' "$*" >&2
  failed=1
}

for file in "${reachable[@]}" "${materializers[@]}" "${dry_run_only[@]}" \
  tools/kdl-check/Cargo.toml tools/kdl-check/Cargo.lock tools/kdl-check/src/main.rs; do
  [ -f "$file" ] || fail "preflight allowlist target is missing: $file"
done

grep -Fxq 'bin/overnight.sh --dry-run > "$plan"' bin/check-overnight-policy.sh ||
  fail "overnight policy gate does not invoke the runner in exact --dry-run mode"

mapfile -t direct < <(
  awk '$1 ~ /^bin\/[a-z0-9-]+\.sh$/ { print $1 }' bin/check-corpus.sh |
    LC_ALL=C sort -u
)
expected_direct=(
  bin/check-agent-new-interview-attempts-mutations.sh
  bin/check-agent-new-interview-attempts.sh
  bin/check-agent-new-renderer-security.sh
  bin/check-canonical-agent-template-mutations.sh
  bin/check-event-first.sh
  bin/check-fixture-reset-terminal.sh
  bin/check-harness-contract.sh
  bin/check-kdl-parse.sh
  bin/check-model-policy-mutations.sh
  bin/check-model-policy.sh
  bin/check-no-pii-history.sh
  bin/check-no-pii.sh
  bin/check-overnight-policy.sh
  bin/check-preflight-safety.sh
  bin/check-retired-surfaces.sh
  bin/check-run-history.sh
  bin/check-st2-pin-consistency.sh
  bin/check-st2-semantic.sh
  bin/check-vrs-scope-drift.sh
  bin/check-vrs-variations.sh
  bin/check-weird-git-setup.sh
  bin/generate-catalog.sh
  bin/model-agent-inventory.sh
)
if [ "${direct[*]}" != "${expected_direct[*]}" ]; then
  fail "check-corpus.sh direct command set differs from the reviewed allowlist"
  diff -u <(printf '%s\n' "${expected_direct[@]}") <(printf '%s\n' "${direct[@]}") >&2 || true
fi

for file in "${reachable[@]}"; do
  [ "$file" = "bin/check-preflight-safety.sh" ] && continue
  while IFS= read -r hit; do
    line="${hit#*:}"
    case "$line" in
      *'st2 --version'*) ;;
      *'st2 ls '*) ;;
      *'st2 validate '*) ;;
      *'st2 up '*'--materialize-only'*) ;;
      *) fail "$file contains a non-allowlisted st2 command: $hit" ;;
    esac
  done < <(
    rg -n --no-heading --pcre2 \
      '^[[:space:]]*(?!#).*(^|[;&|()])[[:space:]]*st2[[:space:]]' "$file" || true
  )
  if rg -n --pcre2 \
    '^[[:space:]]*(?!#).*(^|[;&|()])[[:space:]]*(exec[[:space:]]+)?(claude|codex)[[:space:]]+-' \
    "$file"; then
    fail "$file can launch a model provider"
  fi
done

for file in \
  bin/check-harness-contract.sh \
  bin/check-vrs-scope-drift.sh \
  bin/check-vrs-variations.sh \
  bin/check-weird-git-setup.sh; do
  grep -Fxq '  rm -rf -- "$scratch"' "$file" ||
    fail "$file does not clean its Git-object scratch tree noninteractively"
done

for file in "${materializers[@]}"; do
  if rg -n --pcre2 \
    '^[[:space:]]*(?!#).*((^|[;&|][[:space:]]*)st2[[:space:]]+(eval|up|down|pty|shell)|exec[[:space:]]+(claude|codex)[[:space:]]|(^|[;&|][[:space:]]*)(claude|codex)[[:space:]]+-|curl[[:space:]]|wget[[:space:]]|ssh[[:space:]]|gh[[:space:]]|(^|[;&|][[:space:]]*)eval[[:space:]])' \
    "$file"; then
    fail "$file is not a parser/fs/git-only offline materializer"
  fi
done

grep -Fxq 'kdl = { version = "=6.7.1", default-features = false }' tools/kdl-check/Cargo.toml ||
  fail "parser dependency is not exactly locked to kdl 6.7.1"
if rg -n \
  'std::(net|os::unix::process)|Command|CommandExt|Stdio|Child|reqwest|tokio|st2|claude|codex' \
  tools/kdl-check/src/main.rs; then
  fail "parser source gained a process, network, st2, or provider path"
fi
if rg -n \
  'st2[[:space:]]+(eval|up|down|pty)|(^|[;&|[:space:]])(claude|codex)[[:space:]]' \
  bin/check-kdl-parse.sh; then
  fail "parser wrapper gained a reconcile, PTY, or provider command"
fi

if [ "$failed" -eq 0 ]; then
  printf 'PASS: free preflight reachability is limited to %d reviewed scripts, %d offline materializers, %d dry-run-only runner, and the locked parser\n' \
    "${#reachable[@]}" "${#materializers[@]}" "${#dry_run_only[@]}"
fi
exit "$failed"
