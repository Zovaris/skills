#!/usr/bin/env bash
# warden: zero-token watcher for a batch's cards (a thin wrapper over smithy wait).
#   watch.sh [batch] [max-minutes=50] [--all]
# Wakes when a changed card's stage is decide, stuck, verify (pr_open or ready), merged, reported
# or dropped, or a card newly goes stale; --all wakes on any card change. Exit 0 = something to
# act on, 4 = heartbeat. To also wake on GitHub events, call smithy wait with more targets.
set -uo pipefail
DIR="$(cd "$(dirname "$0")" && pwd -P)"
all=(); args=()
for a in "$@"; do [ "$a" = --all ] && all=(--all) || args+=("$a"); done
exec "$DIR/smithy" wait "batch:${args[0]:-}" --max "${args[1]:-50}" --every 10 ${all[@]+"${all[@]}"}
