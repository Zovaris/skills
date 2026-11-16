#!/usr/bin/env bash
# foreman: zero-token watcher. Blocks until a card needs the foreman, then prints those cards and
# exits, so the foreman wakes only when there is something to do.
#   watch.sh [batch] [max-minutes=50] [--all]
# Default (actionable): wakes only when a changed card's stage is decide, stuck, verify (pr_open
# or ready), merged, reported or dropped, or a card newly goes stale. Progress updates
# (phase/progress while working or waiting) don't wake it. --all wakes on any card change.
# Run it in the background where the harness wakes on exit; else in the foreground.
# Exit 0 = something to act on, 4 = heartbeat (nothing within max-minutes).
set -uo pipefail
DIR="$(cd "$(dirname "$0")" && pwd -P)"
all=0; args=()
for a in "$@"; do [ "$a" = --all ] && all=1 || args+=("$a"); done
batch="${args[0]:-}"; max="${args[1]:-50}"
since="$(node -e "console.log(new Date().toISOString())")"
end=$(( $(date +%s) + max * 60 ))
board() { node "$DIR/status.js" board $batch --json 2>/dev/null; }
stuck_before="$(board | jq -r '[.items[] | select(.stage=="stuck") | .id] | join(",")')"
ACT='["decide","stuck","verify","merged","reported","dropped"]'
while [ "$(date +%s)" -lt "$end" ]; do
  b="$(board)"
  if [ $all -eq 1 ]; then sel='.items[] | select(.updated != null and .updated > $s)'
  else sel='.items[] | select(.updated != null and .updated > $s and (.stage as $g | $act | index($g)))'; fi
  hits="$(jq -r --arg s "$since" --argjson act "$ACT" "$sel"' | "\(.id)  \(.stage)  \(.phase)  \(.progress // "-")  \(.text)"' <<<"$b")"
  [ -n "$hits" ] && { echo "$hits"; exit 0; }
  stuck_now="$(jq -r '[.items[] | select(.stage=="stuck") | .id] | join(",")' <<<"$b")"
  if [ "$stuck_now" != "$stuck_before" ] && [ -n "$stuck_now" ]; then echo "stale: $stuck_now"; exit 0; fi
  sleep 20
done
echo "heartbeat: no change in ${max}m"
exit 4
