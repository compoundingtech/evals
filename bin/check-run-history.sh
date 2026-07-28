#!/usr/bin/env bash
# Validate the append-only PASS/FAIL run ledger and its structured usage/receipt references.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"
history="evidence/run-history.tsv"
expected_header=$'run_id\tcell\tcompleted_at_utc\tsource_commit\tst2_commit\tharness\tmodel\teffort\tduration_seconds\tresult\tscore\tusage_json\tcleanup\treceipt'

[ -f "$history" ] || {
  echo "FAIL: missing $history" >&2
  exit 1
}
[ "$(head -n 1 "$history")" = "$expected_header" ] || {
  echo "FAIL: $history has an unexpected header" >&2
  exit 1
}

# During normal authoring, old bytes must remain an exact prefix. Git history remains the durable audit after
# commit; this guard prevents edits/reordering when a contributor appends locally and runs the free preflight.
if git cat-file -e "HEAD:$history" 2>/dev/null; then
  prior="$(mktemp)"
  cleanup_prior() {
    rm -f -- "$prior"
  }
  trap cleanup_prior EXIT
  git show "HEAD:$history" >"$prior"
  prior_size="$(wc -c <"$prior")"
  current_size="$(wc -c <"$history")"
  [ "$current_size" -ge "$prior_size" ] && cmp -n "$prior_size" "$prior" "$history" || {
    echo "FAIL: $history rewrites or removes an existing row; only append new rows" >&2
    exit 1
  }
fi

inventory="$(bin/corpus-inventory.sh --no-header)"
declare -A seen=()
rows=0
passes=0
failures=0
previous_completed=""

while IFS=$'\t' read -r run_id cell completed source_commit st2_commit harness model effort duration result score usage_json cleanup receipt extra; do
  [ "$run_id" != "run_id" ] || continue
  [ -n "$run_id" ] || continue
  [ -z "${extra:-}" ] || {
    echo "FAIL: run-history row $run_id has extra columns" >&2
    exit 1
  }
  [ -z "${seen[$run_id]:-}" ] || {
    echo "FAIL: duplicate run-history id $run_id" >&2
    exit 1
  }
  seen[$run_id]=1

  grep -q "^${cell}"$'\t' <<<"$inventory" || {
    echo "FAIL: run-history row $run_id names missing cell $cell" >&2
    exit 1
  }
  [[ "$completed" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]] || {
    echo "FAIL: run-history row $run_id has invalid completed_at_utc $completed" >&2
    exit 1
  }
  if [ -n "$previous_completed" ] && [[ "$completed" < "$previous_completed" ]]; then
    echo "FAIL: run-history row $run_id is out of chronological append order" >&2
    exit 1
  fi
  previous_completed="$completed"

  [[ "$source_commit" =~ ^[0-9a-f]{40}$ ]] &&
    git cat-file -e "$source_commit^{commit}" 2>/dev/null || {
      echo "FAIL: run-history row $run_id has unavailable source commit $source_commit" >&2
      exit 1
    }
  [[ "$st2_commit" =~ ^[0-9a-f]{40}$ ]] || {
    echo "FAIL: run-history row $run_id has non-exact st2 commit $st2_commit" >&2
    exit 1
  }
  case "$harness" in
    Claude)
      [ "$model" = "claude-sonnet-5" ] && [ "$effort" = "medium" ] || {
        echo "FAIL: run-history row $run_id has invalid Claude model/effort" >&2
        exit 1
      }
      ;;
    Codex)
      [ "$model" = "gpt-5.6-sol" ] && [ "$effort" = "medium" ] || {
        echo "FAIL: run-history row $run_id has invalid Codex model/effort" >&2
        exit 1
      }
      ;;
    mixed)
      [ "$model" = "claude-sonnet-5+gpt-5.6-sol" ] && [ "$effort" = "medium" ] || {
        echo "FAIL: run-history row $run_id has invalid mixed model/effort" >&2
        exit 1
      }
      ;;
    model-free)
      [ "$model" = "-" ] && [ "$effort" = "-" ] || {
        echo "FAIL: run-history row $run_id gives a model to a model-free run" >&2
        exit 1
      }
      ;;
    *)
      echo "FAIL: run-history row $run_id has unknown harness $harness" >&2
      exit 1
      ;;
  esac
  [[ "$duration" =~ ^[0-9]+$ ]] || {
    echo "FAIL: run-history row $run_id has invalid duration $duration" >&2
    exit 1
  }
  case "$result" in
    PASS) ((passes += 1)) ;;
    FAIL) ((failures += 1)) ;;
    *)
      echo "FAIL: run-history row $run_id has invalid result $result" >&2
      exit 1
      ;;
  esac
  [[ "$score" =~ ^[0-9]+/[0-9]+$ ]] || {
    echo "FAIL: run-history row $run_id has invalid score $score" >&2
    exit 1
  }
  jq -e '
    type == "object" and
    (.declared_seats | type == "number") and
    (.api_equivalent_usd | type == "number")
  ' <<<"$usage_json" >/dev/null || {
    echo "FAIL: run-history row $run_id has invalid usage_json" >&2
    exit 1
  }
  case "$cleanup" in green|failed) ;; *)
    echo "FAIL: run-history row $run_id has invalid cleanup state $cleanup" >&2
    exit 1
  esac
  [[ "$receipt" != /* && "$receipt" != *..* && -f "$receipt" ]] || {
    echo "FAIL: run-history row $run_id has missing or unsafe receipt $receipt" >&2
    exit 1
  }
  ((rows += 1))
done <"$history"

[ "$rows" -gt 0 ] && [ "$passes" -gt 0 ] && [ "$failures" -gt 0 ] || {
  echo "FAIL: run history must contain both PASS and FAIL rows" >&2
  exit 1
}

printf 'PASS: %d append-only run-history rows validated (%d PASS, %d FAIL) with exact commits, usage, cleanup, and receipts\n' \
  "$rows" "$passes" "$failures"
