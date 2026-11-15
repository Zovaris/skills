#!/usr/bin/env bash
# Runs every offline test. `scripts/drill.sh` (live agent runs) is separate and optional.
set -uo pipefail
cd "$(dirname "$0")/.."
rc=0
scripts/sync-shared.sh --check || rc=1
tests/skills.sh || rc=1
for t in tests/*/run.sh; do bash "$t" || rc=1; done
exit $rc
