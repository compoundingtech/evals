#!/usr/bin/env bash
# Sequential, resumable overnight runner. Paid execution requires the explicit --run flag.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

mode="dry-run"
state_dir=".eval-runs/overnight"
acknowledge_usage=0
allow_informational_reset_banner=0
run_all=0
selected_cells=()

usage() {
  cat <<'EOF'
usage: bin/overnight.sh [--dry-run|--run] [--cell NAME ...|--all] [--state-dir PATH]
                        [--acknowledge-usage-stop] [--allow-informational-reset-banner]

--dry-run                 Print the complete stable inventory; start nothing (default).
--run                     Run the free preflight, then execute the explicitly selected cells.
--cell NAME               Select one maintained model-backed cell; repeat to set exact order.
--all                     Select the complete maintained inventory explicitly.
--state-dir PATH          Durable logs/receipts root (default: .eval-runs/overnight).
--acknowledge-usage-stop  Archive an existing STOPPED guard before an explicitly resumed --run.
--allow-informational-reset-banner
                          Human-reviewed opt-in: continue after only the Codex
                          "N usage limit resets available" banner. This can spend
                          more model quota. Hard quota/rate errors always stop.
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --dry-run)
      mode="dry-run"
      shift
      ;;
    --run)
      mode="run"
      shift
      ;;
    --cell)
      [ "$#" -ge 2 ] || {
        echo "FAIL: --cell requires a name" >&2
        usage >&2
        exit 2
      }
      selected_cells+=("$2")
      shift 2
      ;;
    --all)
      run_all=1
      shift
      ;;
    --state-dir)
      [ "$#" -ge 2 ] || {
        usage >&2
        exit 2
      }
      state_dir="$2"
      shift 2
      ;;
    --acknowledge-usage-stop)
      acknowledge_usage=1
      shift
      ;;
    --allow-informational-reset-banner)
      allow_informational_reset_banner=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [ "$run_all" -eq 1 ] && [ "${#selected_cells[@]}" -gt 0 ]; then
  echo "FAIL: --all and --cell cannot be combined" >&2
  exit 2
fi
if [ "$mode" = "run" ] && [ "$run_all" -eq 0 ] && [ "${#selected_cells[@]}" -eq 0 ]; then
  echo "FAIL: --run requires at least one --cell NAME or explicit --all" >&2
  exit 2
fi

full_inventory="$(mktemp)"
selected_inventory=""
cleanup_inventory() {
  rm -f -- "$full_inventory"
  [ -z "$selected_inventory" ] || rm -f -- "$selected_inventory"
}
trap cleanup_inventory EXIT
bin/corpus-inventory.sh --no-header > "$full_inventory"

inventory="$full_inventory"
selection_label="complete lexical inventory"
if [ "${#selected_cells[@]}" -gt 0 ]; then
  selected_inventory="$(mktemp)"
  declare -A seen_cells=()
  for cell in "${selected_cells[@]}"; do
    if [[ ! "$cell" =~ ^[a-z0-9][a-z0-9-]*$ ]]; then
      echo "FAIL: invalid cell name: $cell" >&2
      exit 2
    fi
    if [ -n "${seen_cells[$cell]+present}" ]; then
      echo "FAIL: duplicate --cell selection: $cell" >&2
      exit 2
    fi
    seen_cells["$cell"]=1
    if ! row="$(awk -F $'\t' -v name="$cell" '$1 == name { print; found=1; exit } END { if (!found) exit 1 }' "$full_inventory")"; then
      echo "FAIL: unknown or retired cell: $cell" >&2
      exit 2
    fi
    IFS=$'\t' read -r _cell harness _models _effort seats _cost _timeout _judges <<< "$row"
    if [ "$harness" = "model-free" ] || [ "$seats" = "0" ]; then
      echo "FAIL: paid queue cannot select model-free cell: $cell" >&2
      exit 2
    fi
    printf '%s\n' "$row" >> "$selected_inventory"
  done
  inventory="$selected_inventory"
  selection_label="explicit CLI order"
elif [ "$run_all" -eq 1 ]; then
  selection_label="explicit full lexical inventory (--all)"
fi

printf '%-30s %-10s %-35s %-7s %-5s %-8s %s\n' \
  CELL HARNESS MODEL EFFORT SEATS COST TIMEOUT
while IFS=$'\t' read -r cell harness models effort seats cost timeout _judges; do
  printf '%-30s %-10s %-35s %-7s %-5s %-8s %s\n' \
    "$cell" "$harness" "$models" "$effort" "$seats" "$cost" "$timeout"
done < "$inventory"

cells="$(wc -l < "$inventory" | tr -d ' ')"
printf '\n%s selected cells; %s; sequential, no overlap.\n' "$cells" "$selection_label"
echo 'USAGE POLICY: a real quota/rate-limit error is a hard stop; an informational'
echo '"N usage limit resets available" banner lets the active cell tear down, records its result,'
echo 'then writes STOPPED before the next cell by default. Resume requires explicit acknowledgement.'
if [ "$allow_informational_reset_banner" -eq 1 ]; then
  echo 'INFORMATIONAL BANNER OPT-IN SELECTED: a passing cell may be followed by more paid model'
  echo 'execution after only the reset-available banner. Hard quota/rate-limit errors still stop.'
else
  echo 'INFORMATIONAL BANNER OPT-IN NOT SELECTED: conservative STOPPED behavior remains active.'
  echo 'A future human-reviewed full run may explicitly add --allow-informational-reset-banner;'
  echo 'that choice can spend more model quota and is not implied by --run.'
fi
if [ "$mode" = "dry-run" ]; then
  echo "DRY RUN ONLY: no preflight command, model, judge, or eval was started."
  if [ "$run_all" -eq 0 ] && [ "${#selected_cells[@]}" -eq 0 ]; then
    echo "NO PAID SELECTION: add repeatable --cell NAME or explicit --all together with --run."
  fi
  exit 0
fi

[ "$(git branch --show-current)" = "main" ] || {
  echo "FAIL: overnight runs require main" >&2
  exit 1
}
[ -z "$(git status --porcelain=v1)" ] || {
  echo "FAIL: overnight runs require a clean worktree" >&2
  exit 1
}

echo
echo "== free preflight (no model seats) =="
bin/check-corpus.sh

mkdir -p "$state_dir/logs" "$state_dir/receipts" "$state_dir/failures" "$state_dir/history"
stop_guard="$state_dir/STOPPED"
if [ -f "$stop_guard" ]; then
  if [ "$acknowledge_usage" -eq 0 ]; then
    echo "STOPPED guard exists; no model will start:" >&2
    sed -n '1,80p' "$stop_guard" >&2
    echo "After reviewing usage, resume explicitly with --acknowledge-usage-stop." >&2
    exit 75
  fi
  archive="$state_dir/history/STOPPED.$(date -u +%Y%m%dT%H%M%SZ)"
  mv -- "$stop_guard" "$archive"
  printf 'archived prior STOPPED guard: %s\n' "$archive"
elif [ "$acknowledge_usage" -eq 1 ]; then
  echo "FAIL: --acknowledge-usage-stop was given but no STOPPED guard exists" >&2
  exit 2
fi

source_commit="$(git rev-parse HEAD)"
st2_version="$(st2 --version)"
hard_usage_pattern='usage[ -]?limit[[:space:]].*(reached|exceeded|exhausted)|rate[ -]?limit|too many requests|quota[[:space:]].*(exceeded|exhausted)|capacity[ -]?limit|(^|[^0-9])429([^0-9]|$)'
informational_usage_pattern='[0-9]+ usage limit resets available'

duration_seconds() {
  local raw="$1" number unit
  if [[ "$raw" =~ ^([0-9]+)(ms|s|m|h)$ ]]; then
    number="${BASH_REMATCH[1]}"
    unit="${BASH_REMATCH[2]}"
  else
    echo "unsupported timeout: $raw" >&2
    return 1
  fi
  case "$unit" in
    ms) echo $(((number + 999) / 1000)) ;;
    s) echo "$number" ;;
    m) echo $((number * 60)) ;;
    h) echo $((number * 3600)) ;;
  esac
}

cell_hash() {
  local cell="$1"
  git ls-files -s "cells/$cell" | sha256sum | cut -d' ' -f1
}

receipt_value() {
  local file="$1" key="$2"
  sed -n "s/^${key}=//p" "$file" | head -1
}

write_record() {
  local destination="$1"
  shift
  local temporary="${destination}.tmp.$$"
  printf '%s\n' "$@" > "$temporary"
  mv -- "$temporary" "$destination"
}

cleanup_timed_out_catalog() {
  local catalog="$1" ref pid_file task_pid
  st2 down --catalog "$catalog" >/dev/null 2>&1 || true
  if [ -d "$catalog/pty" ]; then
    while IFS= read -r ref; do
      [ -z "$ref" ] || st2 pty --catalog "$catalog" kill "$ref" >/dev/null 2>&1 || true
    done < <(
      st2 pty --catalog "$catalog" ls --json 2>/dev/null |
        jq -r '.[] | select(.status == "running") | .name' 2>/dev/null || true
    )
  fi
  if [ -d "$catalog" ]; then
    while IFS= read -r -d '' pid_file; do
      task_pid="$(tr -cd '0-9' < "$pid_file")"
      if [ -n "$task_pid" ] && kill -0 "$task_pid" 2>/dev/null; then
        kill -TERM "$task_pid" 2>/dev/null || true
      fi
    done < <(find "$catalog" -type f -name '*.pid' -print0)
  fi
}

while IFS=$'\t' read -r cell harness models effort seats cost declared_timeout _judges; do
  hash="$(cell_hash "$cell")"
  receipt="$state_dir/receipts/$cell.env"
  if [ -f "$receipt" ] &&
    [ "$(receipt_value "$receipt" result)" = "PASS" ] &&
    [ "$(receipt_value "$receipt" cell_hash)" = "$hash" ] &&
    [ "$(receipt_value "$receipt" st2_version)" = "$st2_version" ]; then
    printf 'SKIP completed: %s (%s)\n' "$cell" "$hash"
    continue
  fi

  stamp="$(date -u +%Y%m%dT%H%M%SZ)"
  log="$state_dir/logs/$cell.$stamp.log"
  watchdog_seconds=$(($(duration_seconds "$declared_timeout") + 180))
  printf '\n== %s: %s, %s, %s seat(s), %s cost, timeout %s (+180s watchdog) ==\n' \
    "$cell" "$harness" "$models" "$seats" "$cost" "$declared_timeout"

  setsid stdbuf -oL -eL st2 eval "./cells/$cell/" --keep > "$log" 2>&1 &
  eval_pid=$!
  catalog="/tmp/st2e-$eval_pid"
  started=$SECONDS
  hard_usage_seen=0
  informational_usage_seen=0
  timed_out=0

  while kill -0 "$eval_pid" 2>/dev/null; do
    if [ "$hard_usage_seen" -eq 0 ] && rg -q -i "$hard_usage_pattern" "$log" 2>/dev/null; then
      hard_usage_seen=1
      echo "USAGE GUARD: hard quota/rate-limit error detected in $cell; teardown may finish, then the run stops."
    fi
    if [ "$informational_usage_seen" -eq 0 ] &&
      rg -q -i "$informational_usage_pattern" "$log" 2>/dev/null; then
      informational_usage_seen=1
      if [ "$allow_informational_reset_banner" -eq 1 ]; then
        echo "USAGE NOTICE: informational reset-available banner detected in $cell; reviewed opt-in permits continuation after a PASS."
      else
        echo "USAGE GUARD: informational reset-available banner detected in $cell; teardown may finish, then the run stops."
      fi
    fi
    if [ $((SECONDS - started)) -ge "$watchdog_seconds" ]; then
      timed_out=1
      echo "WATCHDOG: $cell exceeded $watchdog_seconds seconds; terminating its process group."
      kill -TERM -- "-$eval_pid" 2>/dev/null || true
      for _grace in $(seq 1 15); do
        kill -0 "$eval_pid" 2>/dev/null || break
        sleep 1
      done
      if kill -0 "$eval_pid" 2>/dev/null; then
        echo "WATCHDOG: $cell ignored TERM for 15s; killing its process group."
        kill -KILL -- "-$eval_pid" 2>/dev/null || true
      fi
      break
    fi
    sleep 2
  done

  set +e
  wait "$eval_pid"
  rc=$?
  set -e
  if [ "$timed_out" -eq 1 ]; then
    cleanup_timed_out_catalog "$catalog"
  fi
  if [ "$hard_usage_seen" -eq 0 ] && rg -q -i "$hard_usage_pattern" "$log" 2>/dev/null; then
    hard_usage_seen=1
  fi
  if [ "$informational_usage_seen" -eq 0 ] &&
    rg -q -i "$informational_usage_pattern" "$log" 2>/dev/null; then
    informational_usage_seen=1
  fi

  sed -n '1,240p' "$log"
  completed="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  if [ "$rc" -ne 0 ] || ! grep -Fxq 'VERDICT: PASS' "$log"; then
    failure="$state_dir/failures/$cell.$stamp.env"
    write_record "$failure" \
      "cell=$cell" \
      "result=FAIL" \
      "exit_code=$rc" \
      "timed_out=$timed_out" \
      "hard_usage_warning=$hard_usage_seen" \
      "informational_usage_banner=$informational_usage_seen" \
      "allow_informational_reset_banner=$allow_informational_reset_banner" \
      "source_commit=$source_commit" \
      "cell_hash=$hash" \
      "st2_version=$st2_version" \
      "catalog=$catalog" \
      "log=$log" \
      "completed_at=$completed"
    if [ "$hard_usage_seen" -eq 1 ]; then
      write_record "$stop_guard" \
        "reason=hard-usage-or-rate-limit-error" \
        "cell=$cell" \
        "log=$log" \
        "record=$failure" \
        "stopped_at=$completed"
      echo "STOPPED: hard usage/rate-limit error; guard written to $stop_guard" >&2
      exit 75
    fi
    if [ "$informational_usage_seen" -eq 1 ] &&
      [ "$allow_informational_reset_banner" -eq 0 ]; then
      write_record "$stop_guard" \
        "reason=informational-reset-available-banner" \
        "cell=$cell" \
        "log=$log" \
        "record=$failure" \
        "stopped_at=$completed"
      echo "STOPPED: informational reset-available banner under conservative default; guard written to $stop_guard" >&2
      exit 75
    fi
    echo "STOPPED: $cell failed; durable record: $failure" >&2
    exit 1
  fi

  write_record "$receipt" \
    "cell=$cell" \
    "result=PASS" \
    "source_commit=$source_commit" \
    "cell_hash=$hash" \
    "st2_version=$st2_version" \
    "harness=$harness" \
    "models=$models" \
    "effort=$effort" \
    "model_seats=$seats" \
    "cost_band=$cost" \
    "declared_timeout=$declared_timeout" \
    "hard_usage_warning=$hard_usage_seen" \
    "informational_usage_banner=$informational_usage_seen" \
    "allow_informational_reset_banner=$allow_informational_reset_banner" \
    "catalog=$catalog" \
    "log=$log" \
    "completed_at=$completed"
  printf 'RECEIPT: %s\n' "$receipt"

  if [ "$hard_usage_seen" -eq 1 ]; then
    write_record "$stop_guard" \
      "reason=hard-usage-or-rate-limit-error" \
      "cell=$cell" \
      "log=$log" \
      "receipt=$receipt" \
      "stopped_at=$completed"
    echo "STOPPED before the next cell: hard usage/rate-limit error; guard written to $stop_guard" >&2
    exit 75
  fi
  if [ "$informational_usage_seen" -eq 1 ] &&
    [ "$allow_informational_reset_banner" -eq 0 ]; then
    write_record "$stop_guard" \
      "reason=informational-reset-available-banner" \
      "cell=$cell" \
      "log=$log" \
      "receipt=$receipt" \
      "stopped_at=$completed"
    echo "STOPPED before the next cell: informational reset-available banner under conservative default; guard written to $stop_guard" >&2
    exit 75
  fi
done < "$inventory"

echo
echo "OVERNIGHT COMPLETE: every included cell has a matching PASS receipt."
