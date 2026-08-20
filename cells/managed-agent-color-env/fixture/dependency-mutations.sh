#!/usr/bin/env bash
set -euo pipefail

root="${CATALOG:?CATALOG must be set}"
current_st2="$(command -v st2)"
current_pty="$(command -v pty)"
old_st2="${EVAL_OLD_ST2:?EVAL_OLD_ST2 must point to the accepted 0fed14b executable}"
runtime_dir="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
test -S "$runtime_dir/bus"
export XDG_RUNTIME_DIR="$runtime_dir"

test "$(sha256sum "$current_st2" | awk '{ print $1 }')" = \
  "adbd2099db237c17df3dac29052cb387f4ed99888e7477910c33e518c377a3e8"
test "$(sha256sum "$current_pty" | awk '{ print $1 }')" = \
  "1c9716d435ca56ad9b4f67056d76fa6856cdc08e6bbda1fd4be6f59952e9fde3"
test "$(sha256sum "$old_st2" | awk '{ print $1 }')" = \
  "d61d12b2b1189a391c196ca28f8f4ba69072d14fcbad2571fc29db1f250f4eed"
case "$("$current_st2" --version)" in
  *"(ffdb83c,"*) ;;
  *) printf 'unexpected current st2 identity: %s\n' "$("$current_st2" --version)" >&2; exit 1 ;;
esac
case "$("$old_st2" --version)" in
  *"(0fed14b,"*) ;;
  *) printf 'unexpected control st2 identity: %s\n' "$("$old_st2" --version)" >&2; exit 1 ;;
esac

case_roots=()
cleanup() {
  for case_root in "${case_roots[@]}"; do
    case_pty_root="$case_root/net/pty"
    for id in color.ambient color.explicit; do
      env -u PTY_SESSION PTY_ROOT="$case_pty_root" "$current_pty" kill "$id" >/dev/null 2>&1 || true
      env -u PTY_SESSION PTY_ROOT="$case_pty_root" "$current_pty" rm "$id" >/dev/null 2>&1 || true
    done
    rm -rf -- "$case_root"
  done
}
trap cleanup EXIT

prepare_case() {
  case_root="$root/dependency-$1"
  mkdir -p "$case_root"
  cp -a "$root/net" "$case_root/net"
  case_roots+=("$case_root")
  printf '%s\n' "$case_root"
}

wait_for_file() {
  path="$1"
  for _ in $(seq 1 100); do
    test -s "$path" && return 0
    sleep 0.05
  done
  printf 'timed out waiting for %s\n' "$path" >&2
  return 1
}

prepare_case old-st2
old_st2_root="$case_root"
old_st2_net="$old_st2_root/net"
NO_COLOR=1 XDG_STATE_HOME="$old_st2_root/state" PTY_ROOT="$old_st2_net/pty" \
  PATH="$(dirname "$current_pty"):$PATH" \
  "$old_st2" up --once --catalog "$old_st2_net" --host color >/dev/null
wait_for_file "$old_st2_net/observed/ambient.1"
grep -Fqx 'NO_COLOR=1' "$old_st2_net/observed/ambient.1"
echo "OLD-ST2-INITIAL-COLOR-RED-90c4"

prepare_case stripped-pty
stripped_pty_root="$case_root"
stripped_pty_net="$stripped_pty_root/net"
mkdir -p "$stripped_pty_root/bin"
wrapper="$stripped_pty_root/bin/pty"
apply_wrapper="$stripped_pty_root/stripped-unset-env.log"
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'set -euo pipefail' \
  'args=()' \
  'skip_value=0' \
  'for arg in "$@"; do' \
  '  if test "$skip_value" -eq 1; then' \
  '    printf "%s\\n" "$arg" >>"$STRIP_LOG"' \
  '    skip_value=0' \
  '  elif test "$arg" = "--unset-env"; then' \
  '    skip_value=1' \
  '  else' \
  '    args+=("$arg")' \
  '  fi' \
  'done' \
  'test "$skip_value" -eq 0' \
  'exec "$REAL_PTY" "${args[@]}"' >"$wrapper"
chmod +x "$wrapper"

NO_COLOR=1 REAL_PTY="$current_pty" STRIP_LOG="$apply_wrapper" \
  XDG_STATE_HOME="$stripped_pty_root/state" PTY_ROOT="$stripped_pty_net/pty" \
  PATH="$stripped_pty_root/bin:$PATH" \
  "$current_st2" up --once --catalog "$stripped_pty_net" --host color >/dev/null
wait_for_file "$stripped_pty_net/observed/ambient.1"
grep -Fqx 'NO_COLOR=<unset>' "$stripped_pty_net/observed/ambient.1"
grep -Fqx 'NO_COLOR' "$apply_wrapper"

printf '\034' | NO_COLOR=1 env -u PTY_SESSION PTY_ROOT="$stripped_pty_net/pty" \
  "$current_pty" restart -y --force color.ambient \
  >"$stripped_pty_root/ambient-restart.out" 2>"$stripped_pty_root/ambient-restart.err"
wait_for_file "$stripped_pty_net/observed/ambient.2"
grep -Fqx 'NO_COLOR=1' "$stripped_pty_net/observed/ambient.2"
echo "STRIPPED-PTY-RESTART-COLOR-RED-90c4"

cleanup
trap - EXIT
