#!/usr/bin/env bash
# Prove every included cell starts from a deterministic, rehydratable fixture copy.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

scratch="$(mktemp -d)"
cleanup() {
  rm -rf -- "$scratch"
}
trap cleanup EXIT

hydrate_gitdirs() {
  local root="$1" gitdir target
  while IFS= read -r -d '' gitdir; do
    target="${gitdir%/_git}/.git"
    [ ! -e "$target" ] || {
      echo "FAIL: reset target already exists: $target" >&2
      return 1
    }
    mv -- "$gitdir" "$target"
    # Frozen metadata can track an ignored empty file that the outer corpus cannot carry.
    # Restore only missing index-owned paths after hydration.
    git -C "${target%/.git}" ls-files --deleted -z |
      git -C "${target%/.git}" checkout-index --stdin -z
  done < <(find "$root" -depth -type d -name _git -print0)
}

prepare_reset() {
  local cell="$1" root="$2" script
  case "$cell" in
    signal-rename|signal-rename-codex)
      script="$root/materialize.sh"
      ;;
    weird-git-setup)
      script="$root/setup-megarepo.sh"
      ;;
    *)
      hydrate_gitdirs "$root"
      return
      ;;
  esac

  [ -x "$script" ] || {
    echo "FAIL: deterministic reset materializer is not executable: $script" >&2
    return 1
  }
  if rg -n --pcre2 \
    '^[[:space:]]*(?!#).*((^|[;&|][[:space:]]*)st2[[:space:]]+(eval|up|down|pty|shell)|exec[[:space:]]+(claude|codex)[[:space:]]|(^|[;&|][[:space:]]*)(claude|codex)[[:space:]]+-|curl[[:space:]]|wget[[:space:]]|ssh[[:space:]]|gh[[:space:]]|(^|[;&|][[:space:]]*)eval[[:space:]])' \
    "$script"; then
    echo "FAIL: $cell reset materializer contains a provider/reconcile/network command" >&2
    return 1
  fi
  CATALOG="$root" bash "$script" >/dev/null
}

write_manifest() {
  local root="$1" output="$2" path relative gitdir worktree bare ref
  : > "$output"
  while IFS= read -r -d '' path; do
    relative="${path#"$root"/}"
    if [ -L "$path" ]; then
      printf 'link\t%s\t%s\n' "$relative" "$(readlink "$path")" >> "$output"
    elif [ -f "$path" ]; then
      printf 'file\t%s\t%s\t%s\n' \
        "$relative" "$(stat -c '%a' "$path")" "$(sha256sum "$path" | cut -d' ' -f1)" >> "$output"
    elif [ -d "$path" ]; then
      printf 'dir\t%s\t%s\n' "$relative" "$(stat -c '%a' "$path")" >> "$output"
    fi
  done < <(
    find "$root" -mindepth 1 \
      \( -type d \( -name .git -o -name '*.git' \) -prune \) -o \
      \( -type f -name .git -prune \) -o \
      -print0 |
      sort -z
  )

  while IFS= read -r -d '' gitdir; do
    worktree="${gitdir%/.git}"
    relative="${worktree#"$root"/}"
    printf 'git\t%s\tbranch=%s\ttree=%s\n' \
      "$relative" \
      "$(git -C "$worktree" branch --show-current)" \
      "$(git -C "$worktree" rev-parse 'HEAD^{tree}')" >> "$output"
    git -C "$worktree" ls-files -s |
      LC_ALL=C sort |
      sed "s#^#git-index\t$relative\t#" >> "$output"
  done < <(find "$root" \( -type d -o -type f \) -name .git -print0 | sort -z)

  while IFS= read -r -d '' bare; do
    git --git-dir="$bare" rev-parse --is-bare-repository | grep -Fxq true || continue
    relative="${bare#"$root"/}"
    while IFS= read -r ref; do
      printf 'git-bare-ref\t%s\t%s\ttree=%s\n' \
        "$relative" "$ref" "$(git --git-dir="$bare" rev-parse "$ref^{tree}")" >> "$output"
    done < <(git --git-dir="$bare" for-each-ref --format='%(refname)' | LC_ALL=C sort)
  done < <(find "$root" -type d -name '*.git' -print0 | sort -z)
}

while IFS=$'\t' read -r cell _rest; do
  cell_dir="cells/$cell"
  fixture="$cell_dir/fixture"
  if [ ! -d "$fixture" ]; then
    printf 'PASS: %s has no fixture state to reset\n' "$cell"
    continue
  fi
  if find "$fixture" -type d -name .git -print -quit | grep -q .; then
    echo "FAIL: $cell checks in a live .git directory; freeze it as _git or materialize it" >&2
    exit 1
  fi

  reset_a="$scratch/$cell-a"
  reset_b="$scratch/$cell-b"
  mkdir -p "$reset_a" "$reset_b"
  cp -a "$fixture"/. "$reset_a"/
  cp -a "$fixture"/. "$reset_b"/
  prepare_reset "$cell" "$reset_a"
  prepare_reset "$cell" "$reset_b"

  for reset in "$reset_a" "$reset_b"; do
    while IFS= read -r -d '' gitdir; do
      worktree="${gitdir%/.git}"
      git -C "$worktree" fsck --no-dangling --no-progress >/dev/null
      status="$(git -C "$worktree" status --porcelain=v1)"
      [ -z "$status" ] || {
        echo "FAIL: $cell reset produces dirty Git fixture $worktree" >&2
        printf '%s\n' "$status" >&2
        exit 1
      }
    done < <(find "$reset" \( -type d -o -type f \) -name .git -print0)
  done

  manifest_a="$scratch/$cell-a.manifest"
  manifest_b="$scratch/$cell-b.manifest"
  write_manifest "$reset_a" "$manifest_a"
  write_manifest "$reset_b" "$manifest_b"
  if ! cmp -s "$manifest_a" "$manifest_b"; then
    diff -u "$manifest_a" "$manifest_b" >&2 || true
    echo "FAIL: $cell produces different fresh fixture copies" >&2
    exit 1
  fi
  printf 'PASS: %s fixture resets reproducibly\n' "$cell"
done < <(bin/corpus-inventory.sh --no-header)
