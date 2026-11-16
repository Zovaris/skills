#!/usr/bin/env bash
# Proof for a worker's PR claim, so the warden never trusts a status line alone.
#   verify.sh <repo> <branch> [pr]
# Prints one line: `<verdict> pr=<url> state=<state> head=<sha7> checks=<pass|fail|pending|none> mergeable=<x>`
# Verdicts: green | pending | red | merged | closed | unpushed (local head not on the PR) | no-pr
# Exit 0 for green/merged, 1 otherwise.
set -euo pipefail
[ $# -ge 2 ] || { echo 'usage: verify.sh <repo> <branch> [pr]' >&2; exit 2; }
REPO="$1"; BRANCH="$2"; PR="${3:-}"
cd "$REPO"
if [ -z "$PR" ]; then
  PR="$(gh pr list --head "$BRANCH" --state all --json number -q '.[0].number' 2>/dev/null || true)"
fi
[ -n "$PR" ] || { echo "no-pr branch=$BRANCH"; exit 1; }

J="$(gh pr view "$PR" --json url,state,headRefOid,mergeable,isDraft,statusCheckRollup)"
url=$(jq -r .url <<<"$J"); state=$(jq -r .state <<<"$J"); head=$(jq -r .headRefOid <<<"$J")
mergeable=$(jq -r .mergeable <<<"$J"); draft=$(jq -r .isDraft <<<"$J")
checks=$(jq -r '[.statusCheckRollup[]? | (.conclusion // .state // "PENDING")] |
  if length==0 then "none"
  elif any(.[]; test("FAIL|ERROR|CANCEL|TIMED_OUT|ACTION_REQUIRED";"i")) then "fail"
  elif any(.[]; test("PENDING|QUEUED|IN_PROGRESS|EXPECTED|WAITING";"i")) then "pending"
  else "pass" end' <<<"$J")

local_head="$(git rev-parse --verify -q "refs/heads/$BRANCH" 2>/dev/null || true)"
line() { echo "$1 pr=$url state=$state head=${head:0:7} checks=$checks mergeable=$mergeable draft=$draft"; }

case "$state" in
  MERGED) line merged; exit 0 ;;
  CLOSED) line closed; exit 1 ;;
esac
# A claim is refused when the worker's local branch has commits the PR doesn't.
if [ -n "$local_head" ] && [ "$local_head" != "$head" ] && ! git merge-base --is-ancestor "$local_head" "$head" 2>/dev/null; then
  line unpushed; exit 1
fi
[ "$draft" = true ] && { line pending; exit 1; }
case "$checks" in
  fail) line red; exit 1 ;;
  pending) line pending; exit 1 ;;
esac
[ "$mergeable" = CONFLICTING ] && { line red; exit 1; }
line green
