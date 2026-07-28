#!/usr/bin/env bash
set -euo pipefail

mode="${1:?judge mode required}"
root="${CATALOG:?CATALOG not set}/repo"
[ -d "$root" ] || { echo "FAIL: missing repository at $root"; exit 1; }
base="$(git -C "$root" rev-list --max-parents=0 HEAD)"

case "$mode" in
  feature)
    npm --prefix "$root" test >/dev/null ||
      { echo "FAIL: visible test suite is not green"; exit 1; }
    if ! node --input-type=module - "$root" <<'NODE'
import assert from "node:assert/strict";
import fs from "node:fs";
import { pathToFileURL } from "node:url";
const root = process.argv[2];
const defaults = JSON.parse(fs.readFileSync(`${root}/config/defaults.json`, "utf8"));
assert.deepEqual(defaults.presets.resilient, {
  maxAttempts: 5,
  delaysMs: [100, 300, 900, 1800],
});
const schema = JSON.parse(fs.readFileSync(`${root}/config/schema.json`, "utf8"));
assert.deepEqual(schema.properties.preset.enum, ["standard", "resilient"]);
const { resolveRetryPreset } = await import(pathToFileURL(`${root}/src/retry-presets.js`));
const first = resolveRetryPreset("resilient");
const second = resolveRetryPreset("resilient");
assert.deepEqual(first, {
  maxAttempts: 5,
  delaysMs: [100, 300, 900, 1800],
});
assert.equal(Object.isFrozen(first), true);
assert.equal(Object.isFrozen(first.delaysMs), true);
assert.notEqual(first, second);
assert.notEqual(first.delaysMs, second.delaysMs);
assert.throws(() => resolveRetryPreset("other"), /unknown|preset/i);
NODE
    then
      echo "FAIL: resilient preset does not agree across defaults, schema, and runtime"
      exit 1
    fi
    echo "PASS: resilient preset agrees across defaults, schema, and immutable runtime"
    ;;
  preservation)
    if ! node --input-type=module - "$root" <<'NODE'
import assert from "node:assert/strict";
import fs from "node:fs";
import { pathToFileURL } from "node:url";
const root = process.argv[2];
const defaults = JSON.parse(fs.readFileSync(`${root}/config/defaults.json`, "utf8"));
assert.equal(defaults.defaultPreset, "standard");
assert.deepEqual(defaults.presets.standard, {
  maxAttempts: 3,
  delaysMs: [100, 300],
});
const { defaultPreset, resolveRetryPreset } =
  await import(pathToFileURL(`${root}/src/retry-presets.js`));
assert.equal(defaultPreset, "standard");
assert.deepEqual(resolveRetryPreset(), {
  maxAttempts: 3,
  delaysMs: [100, 300],
});
NODE
    then
      echo "FAIL: standard preset or default selection drifted"
      exit 1
    fi
    echo "PASS: standard remains the unchanged default preset"
    ;;
  operator-docs)
    path="$root/docs/config.md"
    [ -f "$path" ] || { echo "FAIL: missing docs/config.md"; exit 1; }
    ! cmp -s <(git -C "$root" show "$base:docs/config.md") "$path" ||
      { echo "FAIL: operator documentation did not change"; exit 1; }
    rg -q -i 'resilient' "$path" ||
      { echo "FAIL: operator docs omit the resilient preset"; exit 1; }
    rg -q -i 'five|5' "$path" ||
      { echo "FAIL: operator docs omit the resilient attempt count"; exit 1; }
    for delay in 100 300 900 1800; do
      rg -q "(^|[^0-9])${delay}([^0-9]|$)" "$path" ||
        { echo "FAIL: operator docs omit ${delay} ms"; exit 1; }
    done
    rg -q -i 'standard.*default|default.*standard' "$path" ||
      { echo "FAIL: operator docs no longer identify standard as default"; exit 1; }
    echo "PASS: operator docs accurately describe both preset contracts"
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
  regression)
    scratch="$(mktemp -d)"
    trap 'rm -r -- "$scratch"' EXIT
    git -C "$root" archive HEAD | tar -x -C "$scratch"
    for path in config/defaults.json config/schema.json src/retry-presets.js; do
      git -C "$root" show "$base:$path" > "$scratch/$path"
    done
    if npm --prefix "$scratch" test >/dev/null 2>&1; then
      echo "FAIL: HEAD tests stay green with all seeded product representations"
      exit 1
    fi
    echo "PASS: resilient-preset regression is RED on seeded product surfaces"
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
        config/defaults.json|config/schema.json|src/retry-presets.js|test/retry-presets.test.js|docs/config.md) ;;
        *) echo "FAIL: change escaped the allowed repository surface: $path"; exit 1 ;;
      esac
    done <<< "$changed"
    echo "PASS: clean commit changed only the five requested product surfaces"
    ;;
  *)
    echo "FAIL: unknown judge mode $mode"
    exit 2
    ;;
esac

