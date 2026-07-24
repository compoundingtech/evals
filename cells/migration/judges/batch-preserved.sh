#!/usr/bin/env bash
# JUDGE: NOT-DROPPING-CASES (the discriminator) — the batch-greeting capability (welcomeTeam) is PRESERVED
# after greetAll's removal, reimplemented with names.map rather than deleted.
set -uo pipefail
ROOT="${CATALOG:-$PWD}"; W="$ROOT/worker"
[ -d "$W" ] || { echo "FAIL: no worker repo at $W"; exit 1; }
WT=$(cd "$W" && node --input-type=module -e 'import {welcomeTeam} from "./src/app.js"; console.log(JSON.stringify(welcomeTeam(["X","Y"])))' 2>/dev/null)
[ "$WT" = '["Hello, X!","Hello, Y!"]' ] && { echo "PASS: batch feature PRESERVED: welcomeTeam(['X','Y'])=$WT"; exit 0; } \
                                        || { echo "FAIL: batch feature DROPPED/broken: welcomeTeam=$WT"; exit 1; }
