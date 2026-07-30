#!/usr/bin/env bash
set -euo pipefail

fixture_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
candidate="${1:?usage: judge-task.sh CANDIDATE_REPOSITORY}"
seed="$fixture_root/task-repo"

test -f "$candidate/src/report.mjs"

mapfile -t seed_files < <(
  cd "$seed"
  find . -type f -print | LC_ALL=C sort
)
mapfile -t candidate_files < <(
  cd "$candidate"
  find . -type f ! -path './.git/*' -print | LC_ALL=C sort
)
test "${seed_files[*]}" = "${candidate_files[*]}"

while IFS= read -r relative; do
  case "$relative" in
    ./src/report.mjs) continue ;;
  esac
  cmp -s "$seed/${relative#./}" "$candidate/${relative#./}"
done < <(printf '%s\n' "${seed_files[@]}")

(
  cd "$candidate"
  npm test
)
CANDIDATE_REPORT="$candidate/src/report.mjs" \
  node --test "$fixture_root/judges/report.test.mjs"

echo "ARM-NEUTRAL-TASK-JUDGE-GREEN-43af"
