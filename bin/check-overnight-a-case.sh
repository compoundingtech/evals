#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf -- "$tmp"' EXIT
git clone -q --no-hardlinks "$repo_root" "$tmp/repo"
git -C "$tmp/repo" switch -q main
mkdir -p "$tmp/fake"
cat > "$tmp/fake/st2" <<'EOF'
#!/usr/bin/env bash
real=/home/myobie/.local/state/st2/releases/v0.2.0+9887b28/st2
if [ "$1" = eval ]; then
  echo 'USAGE_JSON={"cost_usd":0.01,"status":"failed"}'
  echo 'VERDICT: FAIL'
  exit 1
fi
exec "$real" "$@"
EOF
chmod +x "$tmp/fake/st2"
set +e
OVN_TEST_FAKE=1 OVN_TEST_FAKE_COMMAND="$tmp/fake/st2" OVN_TEST_WATCHDOG_EXTRA=0 \
  bash "$tmp/repo/bin/overnight.sh" --run --cell hook-integrity --cell pty-send-peek --state-dir "$tmp/state" >"$tmp/out" 2>&1
rc=$?
set -e
printf 'A_CASE_RC=%s\n' "$rc"
sed -n '1,20p' "$tmp/out"
exit "$rc"
