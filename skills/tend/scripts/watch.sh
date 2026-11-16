#!/usr/bin/env bash
# tend: zero-token wait for new or changed PRs / issues (a thin wrapper over smithy wait).
#   watch.sh [prs|issues|all] [--label <l>] [--every <sec>] [--max-min <min>]
# Prints `pr <n> new|updated <url>` / `issue <n> new|updated <url>`; exit 0 on change, 4 on
# heartbeat. PRs: yours, a warden batch's, or with --label. Issues: with --label (default `agent`).
set -uo pipefail
DIR="$(cd "$(dirname "$0")" && pwd -P)"
scope="$("$DIR/smithy" config get tend.watch 2>/dev/null || echo prs)"; label=""; extra=()
case "${1:-}" in prs|issues|all) scope="$1"; shift ;; esac
while [ $# -gt 0 ]; do case "$1" in
  --label) label="$2"; shift 2 ;; --every) extra+=(--every "$2"); shift 2 ;; --max-min) extra+=(--max "$2"); shift 2 ;;
  *) echo "unknown option $1" >&2; exit 2 ;; esac; done
t=()
[ "$scope" != issues ] && t+=("prs${label:+:$label}")
[ "$scope" != prs ] && t+=("issues:${label:-$("$DIR/smithy" config get tend.label 2>/dev/null || echo agent)}")
exec "$DIR/smithy" wait "${t[@]}" --events new,updated ${extra[@]+"${extra[@]}"}
