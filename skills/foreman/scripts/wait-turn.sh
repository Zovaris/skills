#!/usr/bin/env bash
# foreman: a launched worker whose item can't start yet waits here, inside its own session, until
# its prereqs are merged (or pr_open with `stack`) and a slot is free under the batch's `max`.
# Then it claims the slot (state=working) and returns 0. Lets the foreman launch every worker in
# the user's turn, so nothing needs launching later from an event turn.
#   wait-turn.sh <batch> <id> [max-min=9]
# Exit 0 = go; 4 = still waiting after max-min (call it again: one blocking call per turn,
# under the 10-minute tool limit); 2 = usage or unknown item.
set -uo pipefail
DIR="$(cd "$(dirname "$0")" && pwd -P)"
HOME_DIR="${FOREMAN_HOME:-$HOME/.agents/foreman}"
[ $# -ge 2 ] || { echo 'usage: wait-turn.sh <batch> <id> [max-min]' >&2; exit 2; }
batch="$1"; id="$2"; max_min="${3:-9}"; bdir="$HOME_DIR/$batch"
[ -f "$bdir/batch.json" ] || { echo "no batch $batch" >&2; exit 2; }
jq -e --arg id "$id" '.items[] | select(.id == $id)' "$bdir/batch.json" >/dev/null || { echo "no item $id" >&2; exit 2; }
node "$DIR/status.js" set "$batch" "$id" state=waiting phase=waiting >/dev/null
end=$(( $(date +%s) + max_min * 60 ))
card_state() { jq -r '.state // ""' "$bdir/$1.json" 2>/dev/null; }
while :; do
  stack="$(jq -r '.stack // false' "$bdir/batch.json")"
  max="$(jq -r '.max // 3' "$bdir/batch.json")"
  ready=1
  for p in $(jq -r --arg id "$id" '.items[] | select(.id == $id) | (.prereqs // [])[]' "$bdir/batch.json"); do
    st="$(card_state "$p")"
    if [ "$st" = merged ] || { [ "$stack" = true ] && { [ "$st" = pr_open ] || [ "$st" = ready ]; }; }; then :; else ready=0; fi
    [ "$st" = dropped ] && { node "$DIR/status.js" set "$batch" "$id" state=blocked "note=prereq $p was dropped" >/dev/null; exit 0; }
  done
  if [ $ready -eq 1 ] && mkdir "$bdir/.slot.lock" 2>/dev/null; then
    working=0
    for f in "$bdir"/*.json; do
      case "$(basename "$f")" in batch.json) continue ;; esac
      [ "$(jq -r '.state // ""' "$f")" = working ] && working=$((working + 1))
    done
    if [ "$working" -lt "$max" ]; then
      node "$DIR/status.js" set "$batch" "$id" state=working phase=start >/dev/null
      rmdir "$bdir/.slot.lock"; echo "go $id"; exit 0
    fi
    rmdir "$bdir/.slot.lock"
  fi
  [ "$(date +%s)" -ge "$end" ] && break
  sleep 20
done
echo "waiting $id"; exit 4
