#!/usr/bin/env bash
# Prove every check definition is either preflight-reachable or an explicit compatibility alias.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
scratch="$(mktemp -d)"
cleanup() {
  rm -rf -- "$scratch"
}
trap cleanup EXIT

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

copy="$scratch/repo"
mkdir -p "$copy"
cp -a "$repo_root/bin" "$copy/bin"
mkdir -p "$copy/tools"
cp -a "$repo_root/tools/kdl-check" "$copy/tools/kdl-check"
for file in \
  cells/signal-rename/fixture/materialize.sh \
  cells/signal-rename-codex/fixture/materialize.sh \
  cells/weird-git-setup/fixture/setup-megarepo.sh; do
  mkdir -p "$copy/$(dirname "$file")"
  cp -a "$repo_root/$file" "$copy/$file"
done

bash "$copy/bin/check-preflight-safety.sh" >/dev/null ||
  fail "baseline closed-set safety gate is not green"

printf '%s\n' '#!/usr/bin/env bash' 'exit 1' > "$copy/bin/check-unwired-proof.sh"
chmod +x "$copy/bin/check-unwired-proof.sh"
unwired_output="$scratch/unwired.out"
if bash "$copy/bin/check-preflight-safety.sh" >"$unwired_output" 2>&1; then
  fail "an unclassified check definition was accepted"
fi
grep -Fq 'FAIL: check definitions are not a closed set of reachable gates plus explicit compatibility aliases' "$unwired_output" ||
  fail "unclassified-check rejection did not identify the closed-set violation"
grep -Fq '+bin/check-unwired-proof.sh' "$unwired_output" ||
  fail "unclassified-check rejection did not name the new definition"

rm -- "$copy/bin/check-unwired-proof.sh"
mv -- "$copy/bin/check-claude-native.sh" "$copy/bin/check-claude-native.sh.removed"
missing_alias_output="$scratch/missing-alias.out"
if bash "$copy/bin/check-preflight-safety.sh" >"$missing_alias_output" 2>&1; then
  fail "a missing explicitly classified compatibility alias was accepted"
fi
grep -Fq 'FAIL: preflight allowlist target is missing: bin/check-claude-native.sh' "$missing_alias_output" ||
  fail "missing-alias rejection did not name the absent compatibility entrypoint"

printf '%s\n' \
  'PASS: an added unwired check fails the reverse closed-set gate with its exact path' \
  'PASS: a missing explicitly classified compatibility alias fails by exact path'
