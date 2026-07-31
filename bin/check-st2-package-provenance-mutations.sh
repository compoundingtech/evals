#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"
source bin/st2-pin.sh

scratch="$(mktemp -d)"
cleanup() {
  rm -rf -- "$scratch"
}
trap cleanup EXIT

bin/check-st2-package-provenance.sh >/dev/null

mkdir -p "$scratch/other-st2-checkout/bin"
substitute="$scratch/other-st2-checkout/bin/st2"
cat >"$substitute" <<SCRIPT
#!/usr/bin/env bash
printf '%s\\n' '$ST2_VERSION_PREFIX — committed 1 hour ago'
SCRIPT
chmod +x "$substitute"

if bin/check-st2-package-provenance.sh --binary "$substitute" >"$scratch/substitute.log" 2>&1; then
  echo "FAIL: a same-version binary from another st2 checkout satisfied packaged provenance" >&2
  exit 1
fi
grep -Fq "candidate st2 is not the pinned packaged binary" "$scratch/substitute.log" || {
  cat "$scratch/substitute.log" >&2
  echo "FAIL: same-version st2 substitution failed for an unrelated reason" >&2
  exit 1
}

echo "PASS: exact packaged st2 is accepted and a same-version other-checkout binary is rejected"
