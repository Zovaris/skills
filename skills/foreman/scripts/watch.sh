#!/usr/bin/env bash
# foreman: zero-token watcher. Blocks until a worker's status changes or one goes stale, then
# prints the changed rows and exits, so the foreman wakes only when there is something to do.
#   watch.sh [batch] [max-minutes=50]
# Run it in the background (Bash run_in_background, or Monitor); its exit re-invokes the foreman.
# Exit 0 = change, 4 = heartbeat (nothing happened within max-minutes).
set -uo pipefail
DIR="$(cd "$(dirname "$0")" && pwd -P)"
batch="${1:-}"; max="${2:-50}"
since="$(node -e "console.log(new Date().toISOString())")"
end=$(( $(date +%s) + max * 60 ))
stuck_before="$(node "$DIR/status.js" board $batch --json 2>/dev/null | jq -r '[.items[] | select(.stage=="stuck") | .id] | join(",")')"
while [ "$(date +%s)" -lt "$end" ]; do
  if node "$DIR/status.js" board $batch --changed-since "$since" >/dev/null 2>&1; then
    node "$DIR/status.js" board $batch --json | jq -r --arg s "$since" '.items[] | select(.updated != null and .updated > $s) | "\(.id)  \(.stage)  \(.phase)  \(.progress // "-")  \(.text)"'
    exit 0
  fi
  stuck_now="$(node "$DIR/status.js" board $batch --json 2>/dev/null | jq -r '[.items[] | select(.stage=="stuck") | .id] | join(",")')"
  if [ "$stuck_now" != "$stuck_before" ] && [ -n "$stuck_now" ]; then echo "stale: $stuck_now"; exit 0; fi
  sleep 20
done
echo "heartbeat: no change in ${max}m"
exit 4
