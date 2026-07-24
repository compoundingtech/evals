#!/usr/bin/env bash
# JUDGE: no corruption — the visible test suite is GREEN on HEAD, and registered() has no duplicate keys.
# A redo under at-least-once must not corrupt the artifact (register() is last-wins by design).
# PASS (exit 0): suite green + no duplicate dispatch keys.
set -uo pipefail
ROOT="${CATALOG:-$PWD}"
W="$ROOT/worker"
[ -d "$W/.git" ] || { echo "FAIL: no ledger repo at $W"; exit 1; }
fail=0

if ( cd "$W" && node --test >/dev/null 2>&1 ); then echo "PASS: test suite is GREEN on HEAD"; else echo "FAIL: suite is RED on HEAD (corruption)"; fail=1; fi

dupk=$(cd "$W" && node --input-type=module -e '
import { registered } from "./src/dispatch.js";
const reg = registered();
console.log(reg.length !== new Set(reg).size ? "true" : "false");
' 2>/dev/null)
[ "$dupk" = "false" ] && echo "PASS: registered() has no duplicate keys (no dispatch-map corruption)" \
                      || { echo "FAIL: registered() has DUPLICATE keys — dispatch-map corrupted by a redo"; fail=1; }
exit "$fail"
