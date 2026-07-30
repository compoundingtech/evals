#!/usr/bin/env bash
# Materialize each maintained model workspace without st2 and verify its harness-native overlay + hooks.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

selected="all"
if [ "$#" -eq 2 ] && [ "$1" = "--harness" ]; then
  selected="$2"
  case "$selected" in
    Claude|Codex) ;;
    *) echo "usage: bin/check-harness-contract.sh [--harness Claude|Codex]" >&2; exit 2 ;;
  esac
elif [ "$#" -ne 0 ]; then
  echo "usage: bin/check-harness-contract.sh [--harness Claude|Codex]" >&2
  exit 2
fi

inventory="$(mktemp)"
scratch="$(mktemp -d)"
cleanup() {
  rm -f -- "$inventory"
  rm -rf -- "$scratch"
}
trap cleanup EXIT

bin/model-seat-inventory.sh --no-header > "$inventory"

hydrate_gitdirs() {
  local root="$1" gitdir target
  while IFS= read -r -d '' gitdir; do
    target="${gitdir%/_git}/.git"
    [ ! -e "$target" ] || {
      echo "FAIL: materialized target already exists: $target" >&2
      return 1
    }
    mv -- "$gitdir" "$target"
    # Frozen metadata can track an ignored empty file that the outer corpus cannot carry.
    # Restore only missing index-owned paths after hydration.
    git -C "${target%/.git}" ls-files --deleted -z |
      git -C "${target%/.git}" checkout-index --stdin -z
  done < <(find "$root" -depth -type d -name _git -print0)
}

prepare_cell() {
  local cell="$1" root="$2" fixture="cells/$cell/fixture" script
  [ -d "$fixture" ] || {
    echo "FAIL: model-backed cell $cell has no fixture" >&2
    return 1
  }
  cp -a "$fixture"/. "$root"/
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
    echo "FAIL: safe materializer is not executable: $script" >&2
    return 1
  }
  if rg -n --pcre2 \
    '^[[:space:]]*(?!#).*((^|[;&|][[:space:]]*)st2[[:space:]]+(eval|up|down|pty|shell)|exec[[:space:]]+(claude|codex)[[:space:]]|(^|[;&|][[:space:]]*)(claude|codex)[[:space:]]+-|curl[[:space:]]|wget[[:space:]]|ssh[[:space:]]|gh[[:space:]]|(^|[;&|][[:space:]]*)eval[[:space:]])' \
    "$script"; then
    echo "FAIL: $cell materializer contains a provider/reconcile/network command" >&2
    return 1
  fi
  CATALOG="$root" bash "$script" >/dev/null
}

declare -A roots=()
failed=0
checked=0
while IFS=$'\t' read -r cell agent harness workspace st_agent command_line; do
  if [ "$selected" != "all" ] && [ "$harness" != "$selected" ]; then
    continue
  fi
  if [ -z "${roots[$cell]:-}" ]; then
    roots["$cell"]="$scratch/$cell"
    mkdir -p "${roots[$cell]}"
    prepare_cell "$cell" "${roots[$cell]}" || {
      failed=1
      continue
    }
  fi

  relative="${workspace#./}"
  target="${roots[$cell]}/$relative"
  [ -n "$relative" ] || target="${roots[$cell]}"
  if [ ! -d "$target" ]; then
    echo "FAIL: $cell/$agent workspace $workspace was not materialized" >&2
    failed=1
    continue
  fi

  kdl="cells/$cell/$cell.kdl"
  command_text="$(sed -n "${command_line}p" "$kdl")"
  axe_launch=0
  if grep -Fq 'exec axe agent launch ' <<< "$command_text"; then
    axe_launch=1
    grep -Fq -- '--mode managed-unattended' <<< "$command_text" ||
      { echo "FAIL: $cell/$agent Axe launch omits managed-unattended mode" >&2; failed=1; }
    grep -Fq -- '--boot managed-v1' <<< "$command_text" ||
      { echo "FAIL: $cell/$agent Axe launch omits managed-v1 boot contract" >&2; failed=1; }
    ! grep -Fq -- '--account ' <<< "$command_text" ||
      { echo "FAIL: $cell/$agent durably pins an account instead of using Axe selection" >&2; failed=1; }
  fi
  if [ "$harness" = "Claude" ]; then
    [ -s "$target/CLAUDE.md" ] ||
      { echo "FAIL: $cell/$agent has no non-empty CLAUDE.md" >&2; failed=1; continue; }
    grep -Fxq '@PERSONA.md' "$target/CLAUDE.md" ||
      { echo "FAIL: $cell/$agent CLAUDE.md does not load @PERSONA.md" >&2; failed=1; }
    [ -s "$target/PERSONA.md" ] ||
      { echo "FAIL: $cell/$agent has no non-empty PERSONA.md" >&2; failed=1; }
    cmp -s harness/claude-settings.local.json "$target/.claude/settings.local.json" ||
      { echo "FAIL: $cell/$agent does not materialize the canonical Claude hooks" >&2; failed=1; }
    if [ "$axe_launch" -eq 0 ]; then
      grep -Fq 'Read CLAUDE.md.' <<< "$command_text" ||
        { echo "FAIL: $cell/$agent launch does not use its Claude loader" >&2; failed=1; }
    fi
    [ ! -e "$target/.codex/hooks.json" ] ||
      { echo "FAIL: $cell/$agent Claude workspace mixes in Codex hooks" >&2; failed=1; }
  else
    [ -s "$target/AGENTS.md" ] ||
      { echo "FAIL: $cell/$agent has no non-empty AGENTS.md" >&2; failed=1; continue; }
    cmp -s harness/codex-hooks.json "$target/.codex/hooks.json" ||
      { echo "FAIL: $cell/$agent does not materialize the canonical Codex hooks" >&2; failed=1; }
    if [ "$axe_launch" -eq 0 ]; then
      grep -Fq 'Read AGENTS.md.' <<< "$command_text" ||
        { echo "FAIL: $cell/$agent launch does not use its Codex loader" >&2; failed=1; }
      grep -Fq -- '--dangerously-bypass-hook-trust' <<< "$command_text" ||
        { echo "FAIL: $cell/$agent launch does not trust the declared Codex hooks" >&2; failed=1; }
    fi
    [ ! -e "$target/.claude/settings.local.json" ] ||
      { echo "FAIL: $cell/$agent Codex workspace mixes in Claude hooks" >&2; failed=1; }
  fi

  if [ "$st_agent" = "$agent" ] || [[ "$st_agent" == *".$agent" ]]; then
    :
  else
    echo "FAIL: $cell/$agent declares mismatched ST_AGENT $st_agent" >&2
    failed=1
  fi
  ((checked += 1))
done < "$inventory"

[ "$checked" -gt 0 ] || {
  echo "FAIL: no $selected model seats were checked" >&2
  exit 1
}

mapfile -t model_free < <(
  bin/corpus-inventory.sh --no-header |
    awk -F '\t' '$2 == "model-free" { print $1 }'
)
mapfile -t excluded < <(
  tail -n +2 evidence/harness-exclusions.tsv |
    awk -F '\t' '$2 == "cell" { print $1 }' |
    LC_ALL=C sort
)
mapfile -t expected < <(printf '%s\n' "${model_free[@]}" | LC_ALL=C sort)
if [ "${excluded[*]}" != "${expected[*]}" ]; then
  echo "FAIL: evidence/harness-exclusions.tsv does not exactly cover the derived model-free cells" >&2
  diff -u <(printf '%s\n' "${expected[@]}") <(printf '%s\n' "${excluded[@]}") >&2 || true
  failed=1
fi

grep -Fxq $'docs\tjudge:cold-reader\tone-shot offline Claude print grader; no bus identity, DING, or hook surface' \
  evidence/harness-exclusions.tsv || {
    echo "FAIL: the docs cold-reader model subprocess needs its explicit non-agent hook exclusion" >&2
    failed=1
  }

if [ "$failed" -eq 0 ]; then
  printf 'PASS: %d %s model seats materialize and use the canonical harness overlay and hooks\n' \
    "$checked" "$selected"
  printf 'PASS: %d derived model-free cells have explicit harness-hook exclusions\n' \
    "${#expected[@]}"
fi
exit "$failed"
