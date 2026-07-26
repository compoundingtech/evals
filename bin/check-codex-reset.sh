#!/usr/bin/env bash
# Prove selected Codex fixtures reset into clean, repeatable, explicitly personae'd workspaces.
set -euo pipefail

if [ "$#" -eq 0 ]; then
  set -- \
    cells/license-mit-codex \
    cells/signal-rename-codex \
    cells/ghost-bug-codex \
    cells/poisoned-pr-codex \
    cells/fork-in-the-road-codex
fi

scratch_roots=()

cleanup() {
  local scratch
  for scratch in "${scratch_roots[@]}"; do
    if [ -n "$scratch" ] && [ -d "$scratch" ]; then
      rm -rf -- "$scratch"
    elif [ -n "$scratch" ] && [ -f "$scratch" ]; then
      rm -f -- "$scratch"
    fi
  done
}
trap cleanup EXIT

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  return 1
}

hydrate_static_gitdirs() {
  local root="$1" gitdir target

  while IFS= read -r -d '' gitdir; do
    target="${gitdir%/_git}/.git"
    [ ! -e "$target" ] || fail "reset target already exists: $target"
    mv -- "$gitdir" "$target"
  done < <(find "$root" -depth -type d -name _git -print0)
}

prepare_reset() {
  local cell="$1" root="$2" fixture="$cell/fixture"

  cp -R "$fixture"/. "$root"/
  if [ -x "$fixture/materialize.sh" ]; then
    CATALOG="$root" bash "$root/materialize.sh" >/dev/null
  else
    hydrate_static_gitdirs "$root"
  fi

  if find "$root" -type d -name _git -print -quit | grep -q .; then
    fail "$cell reset left an unhydrated _git directory"
  fi
}

write_manifest() {
  local cell="$1" root="$2" output="$3"
  local name="${cell%/}" kdl workspace relative target persona_sha
  local top status origin workspace_count=0

  name="${name##*/}"
  kdl="$cell/$name.kdl"
  : > "$output"

  while IFS= read -r workspace; do
    ((workspace_count += 1))
    relative="${workspace#./}"
    target="$root/$relative"
    if [ -z "$relative" ]; then
      target="$root"
    fi

    [ -d "$target" ] || fail "$cell workspace '$workspace' is absent after reset"
    [ -s "$target/AGENTS.md" ] || fail "$cell workspace '$workspace' lacks a non-empty AGENTS.md after reset"

    persona_sha="$(sha256sum "$target/AGENTS.md" | cut -d' ' -f1)"
    printf 'workspace %s\npersona %s\n' "$workspace" "$persona_sha" >> "$output"

    top="$(git -C "$target" rev-parse --show-toplevel 2>/dev/null || true)"
    if [ "$top" = "$target" ]; then
      git -C "$target" fsck --no-dangling --no-progress >/dev/null
      status="$(git -C "$target" status --porcelain=v1)"
      [ -z "$status" ] || fail "$cell workspace '$workspace' is dirty immediately after reset"

      printf 'branch %s\n' "$(git -C "$target" branch --show-current)" >> "$output"
      printf 'tree %s\n' "$(git -C "$target" rev-parse 'HEAD^{tree}')" >> "$output"
      git -C "$target" ls-files -s | LC_ALL=C sort >> "$output"

      origin="$(git -C "$target" remote get-url origin 2>/dev/null || true)"
      if [ -n "$origin" ] && [ "${origin#/}" != "$origin" ] && [ "${origin#"$root"/}" = "$origin" ]; then
        fail "$cell workspace '$workspace' has an absolute origin outside its reset root"
      fi
    else
      printf 'git none\n' >> "$output"
    fi
  done < <(sed -n 's/^[[:space:]]*workspace[[:space:]]*"\([^"]*\)".*/\1/p' "$kdl")

  [ "$workspace_count" -gt 0 ] || fail "$cell declares no workspaces to reset"
}

for cell in "$@"; do
  name="${cell%/}"
  name="${name##*/}"
  kdl="$cell/$name.kdl"
  fixture="$cell/fixture"

  [ -f "$kdl" ] || fail "$cell has no canonical $name.kdl"
  [ -d "$fixture" ] || fail "$cell has no fixture directory"

  if find "$fixture" -type d -name .git -print -quit | grep -q .; then
    fail "$cell checks in a live .git directory instead of a frozen _git/reset materializer"
  fi

  reset_a="$(mktemp -d)"
  reset_b="$(mktemp -d)"
  scratch_roots+=("$reset_a" "$reset_b")
  manifest_a="$reset_a/.reset-manifest"
  manifest_b="$reset_b/.reset-manifest"

  prepare_reset "$cell" "$reset_a"
  prepare_reset "$cell" "$reset_b"
  write_manifest "$cell" "$reset_a" "$manifest_a"
  write_manifest "$cell" "$reset_b" "$manifest_b"

  if ! cmp -s "$manifest_a" "$manifest_b"; then
    diff -u "$manifest_a" "$manifest_b" >&2 || true
    fail "$cell produces different workspace/persona/git manifests across fresh resets"
  fi

  printf "PASS: %s resets reproducibly into clean, explicitly personae'd workspaces\n" "$cell"
done
