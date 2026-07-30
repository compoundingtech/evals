#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
checker="$repo_root/bin/check-canonical-seat-template.sh"
source_template="$repo_root/cells/agent-new-interview/fixture/agent.kdl.template"
source_publisher="$repo_root/cells/agent-new-interview/fixture/publish-interviewer.sh"
scratch="$(mktemp -d)"
cleanup() {
  rm -rf -- "$scratch"
}
trap cleanup EXIT

cp "$source_template" "$scratch/valid.template"
cp "$source_publisher" "$scratch/publisher.sh"
"$checker" "$scratch/valid.template" "$scratch/publisher.sh" >/dev/null

cp "$source_template" "$scratch/missing-boot.template"
sed -i 's/"--boot" "managed-v1"//' "$scratch/missing-boot.template"
if "$checker" "$scratch/missing-boot.template" "$scratch/publisher.sh" >/dev/null 2>&1; then
  echo "FAIL: canonical template without managed-v1 boot passed" >&2
  exit 1
fi

cp "$source_template" "$scratch/missing-overlay.template"
sed -i '/copy "_templates\/bus.st2.md" ".st2\/bus.md"/d' "$scratch/missing-overlay.template"
if "$checker" "$scratch/missing-overlay.template" "$scratch/publisher.sh" >/dev/null 2>&1; then
  echo "FAIL: canonical template without bus overlay passed" >&2
  exit 1
fi

echo "PASS: removing a required launch axis or canonical overlay fails the template gate"
