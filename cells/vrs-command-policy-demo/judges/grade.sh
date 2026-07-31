#!/usr/bin/env bash
set -euo pipefail

mode="${1:?judge mode required}"
root="${CATALOG:?CATALOG not set}/repo"
[ -d "$root" ] || { echo "FAIL: missing repository at $root"; exit 1; }
base="$(git -C "$root" rev-list --max-parents=0 HEAD)"

run_node() {
  node --input-type=module - "$root"
}

case "$mode" in
  generator)
    if ! run_node <<'NODE'
import assert from "node:assert/strict";
import { pathToFileURL } from "node:url";
const root = process.argv[2];
const api = await import(pathToFileURL(`${root}/src/index.js`));

for (const workspace of [
  "/srv/orbit/nightly build",
  `/srv/orbit/O'Brien`,
  "/srv/orbit/#release",
  String.raw`C:\orbit\build`,
]) {
  const task = api.buildWorkerTask({ id: "build", workspace });
  assert.equal(task.workspace, workspace);
  assert.equal(api.validateCatalog({ tasks: [task] }).ok, true);
  const argv = api.firstCommandArgv(task.command);
  assert.equal(argv.includes(workspace), true);
  assert.equal(argv.filter((word) =>
    word === "-p" || word === "--policy" || word.startsWith("--policy=")
  ).length, 1);
}
NODE
    then
      echo "FAIL: generated task does not preserve hostile workspace bytes through shell, JSON, and validation"
      exit 1
    fi
    echo "PASS: generated policies round-trip exact hostile workspace bytes"
    ;;
  validation)
    if ! run_node <<'NODE'
import assert from "node:assert/strict";
import { pathToFileURL } from "node:url";
const root = process.argv[2];
const { quoteShellWord, validateCatalog } =
  await import(pathToFileURL(`${root}/src/index.js`));
const workspace = "/srv/orbit/build";
const base = { id: "build", kind: "worker", active: true, workspace };
const policy = JSON.stringify({ workspaces: { [workspace]: { mode: "sandboxed" } } });
const validCommands = [
  `orbit worker -p ${quoteShellWord(policy)}`,
  `exec orbit worker --policy ${quoteShellWord(policy)}`,
  `env REGION=eu MODE=ci orbit worker --policy=${quoteShellWord(policy)}`,
];
for (const command of validCommands) {
  assert.equal(validateCatalog({ tasks: [{ ...base, command }] }).ok, true, command);
}

const invalidPolicies = [
  "{",
  JSON.stringify({ workspaces: { "/srv/orbit/build/../build": { mode: "sandboxed" } } }),
  JSON.stringify({ workspaces: { [workspace]: { mode: "trusted" } } }),
  JSON.stringify({
    workspaces: {
      [workspace]: { mode: "sandboxed" },
      "/srv/other": { mode: "sandboxed" },
    },
  }),
  JSON.stringify({ workspaces: [] }),
];
const invalidCommands = [
  "orbit worker",
  "orbit worker --policy",
  ...invalidPolicies.map((value) => `orbit worker --policy ${quoteShellWord(value)}`),
  `orbit worker -p ${quoteShellWord(policy)} --policy ${quoteShellWord(policy)}`,
];
for (const command of invalidCommands) {
  assert.equal(validateCatalog({ tasks: [{ ...base, command }] }).ok, false, command);
}
NODE
    then
      echo "FAIL: structured policy acceptance or fail-closed validation is incomplete"
      exit 1
    fi
    echo "PASS: supported flags pass and missing, duplicate, malformed, wrong-key, wrong-mode, and extra-key policies fail"
    ;;
  command-boundary)
    if ! run_node <<'NODE'
import assert from "node:assert/strict";
import { pathToFileURL } from "node:url";
const root = process.argv[2];
const { quoteShellWord, validateCatalog } =
  await import(pathToFileURL(`${root}/src/index.js`));
const workspace = "/srv/orbit/build";
const base = { id: "build", kind: "worker", active: true, workspace };
const policy = JSON.stringify({ workspaces: { [workspace]: { mode: "sandboxed" } } });
const invalid = [
  `orbit worker --note ${quoteShellWord(`--policy ${policy}`)}`,
  `orbit worker -- --policy ${quoteShellWord(policy)}`,
  `orbit worker; orbit worker --policy ${quoteShellWord(policy)}`,
  `orbit worker && printf %s ${quoteShellWord(`--policy ${policy}`)}`,
];
for (const command of invalid) {
  assert.equal(validateCatalog({ tasks: [{ ...base, command }] }).ok, false, command);
}
const incidental = `printf %s ${quoteShellWord(`orbit worker --policy ${policy}`)}`;
assert.equal(validateCatalog({ tasks: [{ ...base, command: incidental }] }).ok, true);
NODE
    then
      echo "FAIL: validator accepts incidental, post-delimiter, or later-command policy text"
      exit 1
    fi
    echo "PASS: validation follows decoded first-command argv boundaries"
    ;;
  exclusions)
    if ! run_node <<'NODE'
import assert from "node:assert/strict";
import { pathToFileURL } from "node:url";
const root = process.argv[2];
const { validateCatalog } = await import(pathToFileURL(`${root}/src/index.js`));
const ordinary = [
  { id: "inactive", kind: "worker", active: false, workspace: "/srv/x", command: "orbit worker" },
  { id: "helper", kind: "helper", active: true, workspace: "/srv/x", command: "orbit worker" },
  { id: "other", kind: "worker", active: true, workspace: "/srv/x", command: "python build.py" },
  { id: "global", kind: "worker", active: true, command: "orbit worker" },
];
assert.equal(validateCatalog({ tasks: ordinary }).ok, true);
assert.equal(validateCatalog({ tasks: [{ kind: "helper", command: "true" }] }).ok, false);
NODE
    then
      echo "FAIL: subject selection breaks unaffected tasks or ordinary structural validation"
      exit 1
    fi
    echo "PASS: inactive, helper, non-Orbit, and workspaceless tasks remain outside the policy subject"
    ;;
  suite)
    npm --prefix "$root" test >/dev/null ||
      { echo "FAIL: repository test suite is not green"; exit 1; }
    output="$(npm --prefix "$root" run --silent example)" ||
      { echo "FAIL: operator example does not run"; exit 1; }
    [ "$output" = '{"valid":true,"task":"nightly-build"}' ] || {
      echo "FAIL: operator example produced unexpected evidence: $output"
      exit 1
    }
    echo "PASS: repository suite and operator example exercise a validator-accepted generated task"
    ;;
  regression)
    scratch="$(mktemp -d)"
    trap 'rm -rf -- "$scratch"' EXIT

    git -C "$root" archive HEAD | tar -x -C "$scratch"
    git -C "$root" show "$base:src/validate.js" >"$scratch/src/validate.js"
    if npm --prefix "$scratch" test >/dev/null 2>&1; then
      echo "FAIL: HEAD tests stay green with the seeded validator restored"
      exit 1
    fi

    rm -rf -- "$scratch"
    mkdir -p "$scratch"
    git -C "$root" archive HEAD | tar -x -C "$scratch"
    git -C "$root" show "$base:src/generate.js" >"$scratch/src/generate.js"
    if npm --prefix "$scratch" test >/dev/null 2>&1; then
      echo "FAIL: HEAD tests stay green with the seeded generator restored"
      exit 1
    fi
    echo "PASS: HEAD tests kill seeded validator and generator mutations independently"
    ;;
  coupling)
    pattern='node:child_process|from[[:space:]]+["'\"']child_process|exec(Sync|File)?[[:space:]]*\\(|spawn(Sync)?[[:space:]]*\\(|/etc/(passwd|shadow)|os\\.homedir|process\\.env\\.(HOME|USER|LOGNAME)'
    if matches="$(rg -n "$pattern" "$root/src" "$root/test" "$root/examples" 2>/dev/null)" &&
      [ -n "$matches" ]; then
      echo "FAIL: solution couples validation to command execution or machine account state"
      printf '%s\n' "$matches"
      exit 1
    fi
    echo "PASS: command validation remains an inert data transformation"
    ;;
  isolation)
    requirements="docs/architecture/requirements.md"
    spec="docs/architecture/spec.md"
    [ -f "$root/$requirements" ] || { echo "FAIL: protected requirements were deleted"; exit 1; }
    cmp -s <(git -C "$root" show "$base:$requirements") "$root/$requirements" || {
      echo "FAIL: protected requirements differ from the seed"
      exit 1
    }
    [ -f "$root/$spec" ] || { echo "FAIL: living specification was deleted"; exit 1; }
    ! cmp -s <(git -C "$root" show "$base:$spec") "$root/$spec" || {
      echo "FAIL: product behavior changed without updating the living specification"
      exit 1
    }
    [ "$(git -C "$root" rev-list --count "$base"..HEAD)" -ge 1 ] ||
      { echo "FAIL: no post-seed commit"; exit 1; }
    [ -z "$(git -C "$root" status --porcelain=v1)" ] ||
      { echo "FAIL: repository worktree is not clean"; exit 1; }
    changed="$(git -C "$root" diff --name-only "$base"..HEAD)"
    [ -n "$changed" ] || { echo "FAIL: no committed change"; exit 1; }
    while IFS= read -r path; do
      case "$path" in
        src/validate.js|src/generate.js|src/shell.js|src/index.js|test/*.test.js|examples/*.js|README.md|docs/architecture/spec.md) ;;
        *) echo "FAIL: change escaped the allowed repository surface: $path"; exit 1 ;;
      esac
    done <<<"$changed"
    echo "PASS: requirements are intact and the clean committed patch stays on the implementation/test/spec/example surface"
    ;;
  *)
    echo "FAIL: unknown judge mode $mode"
    exit 2
    ;;
esac
