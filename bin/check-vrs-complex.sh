#!/usr/bin/env bash
# Model-free treatment-isolation, oracle, and mutation-validity proof for the
# complex VRS demonstration and matched catalog-activation A/B.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

demo="cells/vrs-command-policy-demo"
present="cells/vrs-catalog-activation-present"
absent="cells/vrs-catalog-activation-absent"
manifest="evidence/vrs-complex-preflight-20260730.tsv"
scratch="$(mktemp -d)"
cleanup() {
  rm -rf -- "$scratch"
}
trap cleanup EXIT

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

hash_tree() {
  local root="$1"
  shift
  (
    cd "$root"
    find . -type f "$@" -print0 |
      LC_ALL=C sort -z |
      while IFS= read -r -d '' file; do
        printf '%s\0' "$file"
        sha256sum "$file" | awk '{ print $1 }'
      done
  ) | sha256sum | awk '{ print $1 }'
}

emit_manifest() {
  printf 'artifact\tsha256\n'
  printf 'command-task\t%s\n' "$(sha256sum "$demo/task.md" | awk '{ print $1 }')"
  printf 'command-kdl\t%s\n' "$(sha256sum "$demo/vrs-command-policy-demo.kdl" | awk '{ print $1 }')"
  printf 'command-judges\t%s\n' "$(hash_tree "$demo/judges")"
  printf 'command-fixture\t%s\n' "$(hash_tree "$demo/fixture/repo" -not -path './_git/*')"
  printf 'catalog-task\t%s\n' "$(sha256sum "$present/task.md" | awk '{ print $1 }')"
  printf 'catalog-kdl\t%s\n' "$(sha256sum "$present/vrs-catalog-activation-present.kdl" | awk '{ print $1 }')"
  printf 'catalog-judges\t%s\n' "$(hash_tree "$present/judges")"
  printf 'catalog-mutations\t%s\n' "$(hash_tree "$present/mutations")"
  printf 'catalog-ordinary-fixture\t%s\n' "$(
    hash_tree "$present/fixture/repo" \
      -not -path './_git/*' \
      -not -path './docs/architecture/*'
  )"
  printf 'catalog-treatment-requirements\t%s\n' "$(
    sha256sum "$present/fixture/repo/docs/architecture/requirements.md" |
      awk '{ print $1 }'
  )"
  printf 'catalog-treatment-spec\t%s\n' "$(
    sha256sum "$present/fixture/repo/docs/architecture/spec.md" |
      awk '{ print $1 }'
  )"
}

if [ "${1:-}" = "--print-manifest" ]; then
  emit_manifest
  exit 0
fi
[ "$#" -eq 0 ] || fail "usage: bin/check-vrs-complex.sh [--print-manifest]"

cmp -s "$present/task.md" "$absent/task.md" ||
  fail "catalog A/B tasks differ"
cmp -s \
  "$present/vrs-catalog-activation-present.kdl" \
  "$absent/vrs-catalog-activation-absent.kdl" ||
  fail "catalog A/B model, team, timeout, or judge declarations differ"
cmp -s "$present/README.md" "$absent/README.md" ||
  fail "catalog A/B cell documentation differs"
diff -ru "$present/judges" "$absent/judges" >/dev/null ||
  fail "catalog A/B blind judges differ"
diff -ru "$present/mutations" "$absent/mutations" >/dev/null ||
  fail "catalog A/B oracle/mutations differ"

cp -a "$present/fixture/repo" "$scratch/present-stripped"
rm -r -- "$scratch/present-stripped/docs/architecture"
rmdir "$scratch/present-stripped/docs"
diff -ru --exclude=_git "$scratch/present-stripped" "$absent/fixture/repo" >/dev/null || {
  echo "FAIL: catalog A/B ordinary fixture differs beyond treatment documents" >&2
  diff -ru --exclude=_git "$scratch/present-stripped" "$absent/fixture/repo" >&2 || true
  exit 1
}
[ "$(find "$present/fixture/repo/docs/architecture" -maxdepth 1 -type f | wc -l)" -eq 2 ] ||
  fail "catalog present treatment does not contain exactly two documents"
[ ! -e "$absent/fixture/repo/docs/architecture/requirements.md" ] ||
  fail "catalog absent condition contains treatment requirements"
[ ! -e "$absent/fixture/repo/docs/architecture/spec.md" ] ||
  fail "catalog absent condition contains treatment specification"

if rg -n -i '(^|[^[:alpha:]])VRS([^[:alpha:]]|$)|HBR-R[0-9]+|ORB-R[0-9]+' \
  "$demo/task.md" "$present/task.md" "$present/judges" "$absent/judges"; then
  fail "neutral task or blind judge leaks a treatment label or requirement identifier"
fi

[ -f "$manifest" ] || fail "missing recorded preflight hash manifest"
actual_manifest="$scratch/manifest.tsv"
emit_manifest >"$actual_manifest"
cmp -s "$manifest" "$actual_manifest" || {
  echo "FAIL: complex VRS preflight hash manifest is stale" >&2
  diff -u "$manifest" "$actual_manifest" >&2 || true
  exit 1
}

hydrate() {
  local cell="$1" name="$2"
  mkdir -p "$scratch/$name"
  cp -a "$cell/fixture/repo" "$scratch/$name/repo"
  mv "$scratch/$name/repo/_git" "$scratch/$name/repo/.git"
}

commit_change() {
  local name="$1" message="$2"
  git -C "$scratch/$name/repo" add -A
  GIT_AUTHOR_DATE=2026-07-30T07:00:00Z GIT_COMMITTER_DATE=2026-07-30T07:00:00Z \
    git -C "$scratch/$name/repo" \
      -c user.name="Oracle Check" -c user.email="oracle@example.invalid" \
      commit -qm "$message"
}

run_judge() {
  local cell="$1" name="$2" mode="$3"
  CATALOG="$scratch/$name" bash "$cell/judges/grade.sh" "$mode"
}

expect_fail() {
  local cell="$1" name="$2" mode="$3"
  local output="$scratch/$name.$mode.out"
  if run_judge "$cell" "$name" "$mode" >"$output" 2>&1; then
    fail "$name unexpectedly passed $mode"
  fi
  rg -q '^FAIL:' "$output" || {
    sed -n '1,100p' "$output" >&2
    fail "$name failed without an explanatory FAIL receipt"
  }
}

install_demo_solution() {
  local name="$1"
  cp "$demo/mutations/solution-validate.js" "$scratch/$name/repo/src/validate.js"
  cp "$demo/mutations/solution-generate.js" "$scratch/$name/repo/src/generate.js"
  cp "$demo/mutations/solution-test.js" "$scratch/$name/repo/test/catalog.test.js"
  cp "$demo/mutations/solution-spec.md" \
    "$scratch/$name/repo/docs/architecture/spec.md"
  commit_change "$name" "implement workspace launch policy"
}

hydrate "$demo" demo-valid
install_demo_solution demo-valid
for mode in generator validation command-boundary exclusions suite regression coupling isolation; do
  run_judge "$demo" demo-valid "$mode" >/dev/null
done

hydrate "$demo" demo-seed-validator
install_demo_solution demo-seed-validator
base="$(git -C "$scratch/demo-seed-validator/repo" rev-list --max-parents=0 HEAD)"
git -C "$scratch/demo-seed-validator/repo" show "$base:src/validate.js" \
  >"$scratch/demo-seed-validator/repo/src/validate.js"
expect_fail "$demo" demo-seed-validator validation

hydrate "$demo" demo-seed-generator
install_demo_solution demo-seed-generator
base="$(git -C "$scratch/demo-seed-generator/repo" rev-list --max-parents=0 HEAD)"
git -C "$scratch/demo-seed-generator/repo" show "$base:src/generate.js" \
  >"$scratch/demo-seed-generator/repo/src/generate.js"
expect_fail "$demo" demo-seed-generator generator

install_catalog_solution() {
  local cell="$1" name="$2"
  cp "$cell/mutations/solution-store.js" "$scratch/$name/repo/src/store.js"
  cp "$cell/mutations/solution-runtime.js" "$scratch/$name/repo/src/runtime.js"
  cp "$cell/mutations/solution-reconcile.js" "$scratch/$name/repo/src/reconcile.js"
  cp "$cell/mutations/solution-test.js" "$scratch/$name/repo/test/catalog.test.js"
  if [ -f "$scratch/$name/repo/docs/architecture/spec.md" ]; then
    cp "$cell/mutations/solution-spec.md" \
      "$scratch/$name/repo/docs/architecture/spec.md"
  fi
  commit_change "$name" "implement host-local catalog activation"
}

for condition in present absent; do
  cell="cells/vrs-catalog-activation-$condition"
  name="catalog-valid-$condition"
  hydrate "$cell" "$name"
  install_catalog_solution "$cell" "$name"
  for mode in activation preservation partition reachability crash adoption coupling regression; do
    run_judge "$cell" "$name" "$mode" >/dev/null
  done
done

for seam_mode in store:partition runtime:adoption reconcile:reachability; do
  seam="${seam_mode%%:*}"
  mode="${seam_mode#*:}"
  name="catalog-seed-$seam"
  hydrate "$present" "$name"
  install_catalog_solution "$present" "$name"
  base="$(git -C "$scratch/$name/repo" rev-list --max-parents=0 HEAD)"
  git -C "$scratch/$name/repo" show "$base:src/$seam.js" \
    >"$scratch/$name/repo/src/$seam.js"
  expect_fail "$present" "$name" "$mode"
done

printf '%s\n' \
  "PASS: catalog A/B task, model/team declaration, timeout, judges, mutations, and ordinary fixtures match" \
  "PASS: only two architecture treatment documents differ; neutral task and blind judges leak no treatment IDs" \
  "PASS: checked-in sha256 manifest covers tasks, declarations, judges, mutations, ordinary fixture, and treatment" \
  "PASS: planted command-policy outcome passes all 8 executable gates in the designed-to-pass condition" \
  "PASS: planted catalog outcome passes all 8 executable gates in both matched conditions" \
  "PASS: seeded validator, generator, store, runtime, and reconciler fail their targeted executable gates"
