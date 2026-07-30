#!/usr/bin/env bash
set -euo pipefail

mode="${1:?judge mode required}"
root="${CATALOG:?CATALOG not set}/repo"
[ -d "$root" ] || { echo "FAIL: missing repository at $root"; exit 1; }
judge_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
base="$(git -C "$root" rev-list --max-parents=0 HEAD)"

case "$mode" in
  activation|preservation|partition|reachability|crash|adoption)
    node "$judge_dir/behavior.mjs" "$mode" "$root" || {
      echo "FAIL: $mode architectural behavior is incomplete"
      exit 1
    }
    ;;
  coupling)
    node "$judge_dir/behavior.mjs" coupling "$root" || {
      echo "FAIL: host-local state changed a remote host or used a global active catalog"
      exit 1
    }
    pattern='node:child_process|from[[:space:]]+["'\"']child_process|exec(Sync|File)?[[:space:]]*\\(|spawn(Sync)?[[:space:]]*\\(|/etc/(passwd|shadow)|os\\.homedir|process\\.env\\.(HOME|USER|LOGNAME)|active/catalog\\.json'
    if matches="$(rg -n "$pattern" "$root/src" "$root/test" 2>/dev/null)" &&
      [ -n "$matches" ]; then
      echo "FAIL: implementation couples host-local reconciliation to a process, account, or global catalog"
      printf '%s\n' "$matches"
      exit 1
    fi
    echo "PASS: storage, runtime, and health remain host-local and process-free"
    ;;
  regression)
    npm --prefix "$root" test >/dev/null ||
      { echo "FAIL: repository test suite is not green"; exit 1; }

    scratch="$(mktemp -d)"
    trap 'rm -rf -- "$scratch"' EXIT
    for seam in store runtime reconcile; do
      rm -rf -- "$scratch"
      mkdir -p "$scratch"
      git -C "$root" archive HEAD | tar -x -C "$scratch"
      git -C "$root" show "$base:src/$seam.js" >"$scratch/src/$seam.js"
      if npm --prefix "$scratch" test >/dev/null 2>&1; then
        echo "FAIL: HEAD tests stay green with seeded $seam implementation restored"
        exit 1
      fi
    done

    requirements="docs/architecture/requirements.md"
    spec="docs/architecture/spec.md"
    if git -C "$root" cat-file -e "$base:$requirements" 2>/dev/null; then
      [ -f "$root/$requirements" ] || {
        echo "FAIL: protected requirements were deleted"
        exit 1
      }
      cmp -s <(git -C "$root" show "$base:$requirements") "$root/$requirements" || {
        echo "FAIL: protected requirements differ from the seed"
        exit 1
      }
      [ -f "$root/$spec" ] || { echo "FAIL: living specification was deleted"; exit 1; }
      ! cmp -s <(git -C "$root" show "$base:$spec") "$root/$spec" || {
        echo "FAIL: product behavior changed without updating the living specification"
        exit 1
      }
    else
      [ ! -e "$root/$requirements" ] || {
        echo "FAIL: control condition invented protected treatment requirements"
        exit 1
      }
    fi

    [ "$(git -C "$root" rev-list --count "$base"..HEAD)" -ge 1 ] ||
      { echo "FAIL: no post-seed commit"; exit 1; }
    [ -z "$(git -C "$root" status --porcelain=v1)" ] ||
      { echo "FAIL: repository worktree is not clean"; exit 1; }
    changed="$(git -C "$root" diff --name-only "$base"..HEAD)"
    [ -n "$changed" ] || { echo "FAIL: no committed change"; exit 1; }
    while IFS= read -r file; do
      case "$file" in
        src/store.js|src/runtime.js|src/reconcile.js|src/index.js|src/candidate.js|test/*.test.js|README.md|docs/architecture/spec.md) ;;
        *) echo "FAIL: change escaped the allowed repository surface: $file"; exit 1 ;;
      esac
    done <<<"$changed"
    echo "PASS: tests kill all three seeded seams and the committed patch preserves its treatment boundary"
    ;;
  *)
    echo "FAIL: unknown judge mode $mode"
    exit 2
    ;;
esac
