#!/usr/bin/env bash
set -euo pipefail

mode="${1:?judge mode required}"
root="${CATALOG:?CATALOG not set}/repo"
[ -d "$root" ] || { echo "FAIL: missing repository at $root"; exit 1; }
base="$(git -C "$root" rev-list --max-parents=0 HEAD)"

case "$mode" in
  library)
    npm --prefix "$root" test >/dev/null ||
      { echo "FAIL: visible test suite is not green"; exit 1; }
    if ! node --input-type=module - "$root" <<'NODE'
import assert from "node:assert/strict";
import { pathToFileURL } from "node:url";
const root = process.argv[2];
const { summarizeChecks } = await import(pathToFileURL(`${root}/src/summary.js`));
assert.deepEqual(
  summarizeChecks([
    { name: "db", ok: true },
    { name: "queue", ok: false },
    { name: "cache", ok: true },
  ]),
  { total: 3, passing: 2, failing: 1 },
);
assert.deepEqual(summarizeChecks([]), { total: 0, passing: 0, failing: 0 });
for (const malformed of [null, {}, [{ name: "db" }], [{ ok: "yes" }]]) {
  assert.throws(() => summarizeChecks(malformed), /check|array|boolean|ok/i);
}
NODE
    then
      echo "FAIL: summary library contract is incomplete"
      exit 1
    fi
    echo "PASS: summary library returns exact counts and rejects malformed input"
    ;;
  cli)
    command_path="$root/bin/health-summary.js"
    [ -f "$command_path" ] || { echo "FAIL: missing bin/health-summary.js"; exit 1; }
    node --input-type=module - "$root/package.json" <<'NODE'
import assert from "node:assert/strict";
import fs from "node:fs";
const packageJson = JSON.parse(fs.readFileSync(process.argv[2], "utf8"));
assert.equal(
  packageJson.bin?.["health-summary"]?.replace(/^\.\//, ""),
  "bin/health-summary.js",
);
NODE
    scratch="$(mktemp -d)"
    trap 'rm -r -- "$scratch"' EXIT
    printf '%s\n' '[{"name":"db","ok":true},{"name":"queue","ok":false}]' > "$scratch/failing.json"
    printf '%s\n' '[{"name":"db","ok":true}]' > "$scratch/passing.json"
    set +e
    failing_output="$(node "$command_path" "$scratch/failing.json" 2>"$scratch/failing.err")"
    failing_rc=$?
    set -e
    [ "$failing_rc" -eq 2 ] || {
      echo "FAIL: failing summary exits $failing_rc instead of 2"
      exit 1
    }
    [ "$failing_output" = '{"total":2,"passing":1,"failing":1}' ] || {
      echo "FAIL: failing summary output is not exact compact JSON"
      exit 1
    }
    passing_output="$(node "$command_path" "$scratch/passing.json" 2>"$scratch/passing.err")" || {
      echo "FAIL: all-passing summary did not exit 0"
      exit 1
    }
    [ "$passing_output" = '{"total":1,"passing":1,"failing":0}' ] || {
      echo "FAIL: passing summary output is not exact compact JSON"
      exit 1
    }
    echo "PASS: packaged CLI prints exact JSON and exits 0/2 as required"
    ;;
  regression)
    scratch="$(mktemp -d)"
    trap 'rm -r -- "$scratch"' EXIT
    git -C "$root" archive HEAD | tar -x -C "$scratch"
    git -C "$root" show "$base:src/summary.js" > "$scratch/src/summary.js"
    if npm --prefix "$scratch" test >/dev/null 2>&1; then
      echo "FAIL: HEAD tests stay green with the seeded summary library"
      exit 1
    fi
    echo "PASS: health-summary regression is RED on the seeded library"
    ;;
  readme)
    path="$root/README.md"
    ! cmp -s <(git -C "$root" show "$base:README.md") "$path" ||
      { echo "FAIL: README did not change"; exit 1; }
    rg -q 'health-summary' "$path" ||
      { echo "FAIL: README has no health-summary usage"; exit 1; }
    plain="$(tr -d '\`' < "$path")"
    rg -q -i '(^|[^0-9])0([^0-9]|$).*(pass|success|failing[^.]*0)' <<< "$plain" ||
      { echo "FAIL: README omits success exit status 0"; exit 1; }
    rg -q -i '(^|[^0-9])2([^0-9]|$).*(fail|unhealthy|nonzero)' <<< "$plain" ||
      { echo "FAIL: README omits failure exit status 2"; exit 1; }
    echo "PASS: README includes command usage and both exit statuses"
    ;;
  changelog)
    path="$root/CHANGELOG.md"
    ! cmp -s <(git -C "$root" show "$base:CHANGELOG.md") "$path" ||
      { echo "FAIL: changelog did not change"; exit 1; }
    rg -q -i 'health[[:space:]_-]*summary|summary[[:space:]_-]*(command|cli)' "$path" ||
      { echo "FAIL: changelog does not record the health-summary command"; exit 1; }
    echo "PASS: changelog records the shipped health-summary command"
    ;;
  governance)
    for path in docs/governance/requirements.md docs/governance/spec.md; do
      if git -C "$root" cat-file -e "$base:$path" 2>/dev/null; then
        [ -f "$root/$path" ] || { echo "FAIL: seeded governing material was deleted"; exit 1; }
        cmp -s <(git -C "$root" show "$base:$path") "$root/$path" || {
          echo "FAIL: seeded governing material changed: $path"
          exit 1
        }
      else
        [ ! -e "$root/$path" ] || {
          echo "FAIL: control condition invented governing material: $path"
          exit 1
        }
      fi
    done
    echo "PASS: seeded governance-document condition is byte-identical"
    ;;
  isolation)
    [ "$(git -C "$root" rev-list --count "$base"..HEAD)" -ge 1 ] ||
      { echo "FAIL: no post-seed commit"; exit 1; }
    [ -z "$(git -C "$root" status --porcelain=v1)" ] ||
      { echo "FAIL: repository worktree is not clean"; exit 1; }
    changed="$(git -C "$root" diff --name-only "$base"..HEAD)"
    [ -n "$changed" ] || { echo "FAIL: no committed change"; exit 1; }
    while IFS= read -r path; do
      case "$path" in
        src/summary.js|bin/health-summary.js|package.json|README.md|CHANGELOG.md) ;;
        test/*.test.js)
          [[ "${path#test/}" != */* ]] ||
            { echo "FAIL: test change escaped the one-level test surface: $path"; exit 1; }
          ;;
        *) echo "FAIL: change escaped the allowed repository surface: $path"; exit 1 ;;
      esac
    done <<< "$changed"
    echo "PASS: clean commit changed only the seven definition-of-done surfaces"
    ;;
  *)
    echo "FAIL: unknown judge mode $mode"
    exit 2
    ;;
esac
