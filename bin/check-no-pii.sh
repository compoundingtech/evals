#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# check-no-pii — a publish-time backstop. Before you share your own cells, scan
# the tree for machine-specific absolute paths (and any private tokens you name)
# that shouldn't leave your machine. Exit 1 with offenders if any hit; 0 = clean.
#
#   check-no-pii.sh [DIR]                         # scan DIR (default: publishable repo files)
#   PII_TOKENS='alex|widgetco|acme-internal' check-no-pii.sh cells/my-cell
#
# By default it flags absolute home/volume paths (…/Users/<you>/…, /home/<you>/…,
# /Volumes/<disk>/…) — the usual way a machine path sneaks into a fixture. Add
# your own names/handles/private-repo tokens via PII_TOKENS (pipe-separated).
# ─────────────────────────────────────────────────────────────────────────────
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/.." && pwd)"
ROOT="${1:-$REPO}"
SCRATCH="$(mktemp -d)"
cleanup() {
  rm -rf -- "$SCRATCH"
}
trap cleanup EXIT

# Things that almost never belong in a portable, shareable fixture:
#  - absolute machine paths (raw and the dash-encoded scratchpad form)
#  - session-id UUIDs
#  - <name>-claude style agent handles (a specific-harness identity) — but NOT a
#    `$var-claude` session-name construction or a `configure-claude-agent.sh` filename
MACHINE_PATHS='/Users/[^/[:space:]"]+|/home/[^/[:space:]"]+|/Volumes/[^/[:space:]"]+|/private/tmp|-Volumes-[A-Za-z0-9]|-Users-[A-Za-z0-9]'
SESSION_UUID='[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}'
AGENT_HANDLE='(^|[^$A-Za-z0-9_/])[a-z][a-z0-9]{2,}-claude([^-A-Za-z0-9]|$)'
DEFAULT="${MACHINE_PATHS}|${SESSION_UUID}|${AGENT_HANDLE}"
FORBIDDEN="${PII_TOKENS:+${PII_TOKENS}|}${DEFAULT}"

published_fixture_heads() {
  if [ "$ROOT" = "$REPO" ]; then
    (
      cd "$REPO"
      git ls-files -z --cached --others --exclude-standard |
        while IFS= read -r -d '' path; do
          case "$path" in
            */_git/HEAD) printf '%s\0' "$REPO/$path" ;;
          esac
        done
    )
  else
    find "$ROOT" \
      \( -type d \( -name .git -o -name .build -o -name .sandbox -o -name .personas -o -name node_modules \) -prune \) -o \
      \( -type f -path '*/_git/HEAD' -print0 \)
  fi
}

# Fixture repositories are published with .git renamed to _git. Their compressed object files are binary, so
# grep -I cannot see a machine path that was committed and later deleted. Scan every blob reachable from every
# published fixture ref through Git itself; unreachable implementation debris is outside the published history
# contract and is intentionally ignored.
scan_fixture_history() {
  local head git_dir oid path type match
  local objects="$SCRATCH/objects" blob="$SCRATCH/blob"
  local failed=0

  while IFS= read -r -d '' head; do
    git_dir="${head%/HEAD}"
    if ! git --git-dir="$git_dir" rev-list --objects --all >"$objects"; then
      printf 'ERROR: cannot enumerate reachable objects in %s\n' "$git_dir" >&2
      failed=1
      continue
    fi

    while IFS=' ' read -r oid path; do
      [ -n "$oid" ] || continue
      type="$(git --git-dir="$git_dir" cat-file -t "$oid" 2>/dev/null)" || {
        printf 'ERROR: cannot inspect reachable object %s in %s\n' "$oid" "$git_dir" >&2
        failed=1
        continue
      }
      [ "$type" = "blob" ] || continue
      git --git-dir="$git_dir" cat-file blob "$oid" >"$blob" 2>/dev/null || {
        printf 'ERROR: cannot read reachable blob %s in %s\n' "$oid" "$git_dir" >&2
        failed=1
        continue
      }
      while IFS= read -r match; do
        printf '%s@%s:%s:%s\n' "$git_dir" "$oid" "${path:-<unknown>}" "$match"
      done < <(grep -anEi "$FORBIDDEN" "$blob" 2>/dev/null || true)
    done <"$objects"
  done < <(published_fixture_heads)

  return "$failed"
}

history_status=0
history_hits_file="$SCRATCH/history-hits"
scan_fixture_history >"$history_hits_file" || history_status=$?

if [ "$ROOT" = "$REPO" ]; then
  # Scan exactly what could be published: tracked files plus unignored untracked files. Runtime-local
  # state such as .claude/, .codex/, .convoy/, and smoke logs is intentionally gitignored and excluded.
  mapfile -t HITS < <(
    cd "$REPO"
    git ls-files -z --cached --others --exclude-standard |
      xargs -0 -r grep -IHnEi "$FORBIDDEN" 2>/dev/null |
      grep -vE '^bin/check-no-pii\.sh:' || true
  )
else
  mapfile -t HITS < <(
    grep -rIHnEi "$FORBIDDEN" "$ROOT" \
      --exclude-dir=.git --exclude-dir=.build --exclude-dir=.sandbox \
      --exclude-dir=.personas --exclude-dir=node_modules \
      --exclude='check-no-pii.sh' 2>/dev/null
  )
fi

mapfile -t HISTORY_HITS <"$history_hits_file"
HITS+=("${HISTORY_HITS[@]}")

if [ "$history_status" -ne 0 ]; then
  echo "✗ check-no-pii FAILED — fixture Git history could not be inspected under $ROOT"
  exit 1
elif [ "${#HITS[@]}" -eq 0 ]; then
  echo "✓ check-no-pii CLEAN — no machine paths / listed tokens in $ROOT"
  exit 0
else
  echo "✗ check-no-pii FAILED — ${#HITS[@]} hit(s) in $ROOT:"
  printf '  %s\n' "${HITS[@]}"
  echo "  (portable fixtures use env vars — \$HOME, \${ST_ROOT}, \${EVAL_SANDBOX} — not absolute machine paths.)"
  exit 1
fi
