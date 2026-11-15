#!/usr/bin/env bash
# tend: compact state of one PR, so the loop decides from one line of JSON.
#   pr-state.sh <pr-url|number|branch>
#   pr-state.sh --from <view.json> <threads.json> <compare.json>   offline (tests, fixtures)
# Prints: {"url","state","checks","mergeable","review","unresolved","behind","head","base"}
#   state      OPEN | MERGED | CLOSED
#   checks     pass | fail | pending | none
#   mergeable  MERGEABLE | CONFLICTING | UNKNOWN
#   review     APPROVED | CHANGES_REQUESTED | REVIEW_REQUIRED | none
#   unresolved number of unresolved review threads
#   behind     commits the head is behind its base
set -euo pipefail

summarize() {  # $1 view.json  $2 threads.json  $3 compare.json
  jq -c -n --slurpfile v "$1" --slurpfile t "$2" --slurpfile c "$3" '
    ($v[0]) as $p
    | {
        url: $p.url,
        state: $p.state,
        checks: ([$p.statusCheckRollup[]? | (.conclusion // .state // "PENDING") | ascii_upcase] as $s
                 | if ($s|length)==0 then "none"
                   elif any($s[]; test("FAIL|ERROR|CANCEL|TIMED_OUT|ACTION_REQUIRED|STARTUP_FAILURE")) then "fail"
                   elif any($s[]; test("PENDING|QUEUED|IN_PROGRESS|EXPECTED|WAITING|REQUESTED")) then "pending"
                   else "pass" end),
        mergeable: ($p.mergeable // "UNKNOWN"),
        review: (if ($p.reviewDecision // "") == "" then "none" else $p.reviewDecision end),
        unresolved: ([$t[0].data.repository.pullRequest.reviewThreads.nodes[]? | select(.isResolved | not)] | length),
        behind: ($c[0].behind_by // 0),
        head: $p.headRefName,
        base: $p.baseRefName
      }'
}

if [ "${1:-}" = "--from" ]; then
  [ $# -eq 4 ] || { echo 'usage: pr-state.sh --from <view.json> <threads.json> <compare.json>' >&2; exit 2; }
  summarize "$2" "$3" "$4"; exit 0
fi
[ $# -eq 1 ] || { echo 'usage: pr-state.sh <pr-url|number|branch>' >&2; exit 2; }

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
gh pr view "$1" --json url,number,state,mergeable,reviewDecision,statusCheckRollup,headRefName,baseRefName,headRepositoryOwner,headRepository > "$tmp/view.json"
owner="$(gh repo view --json owner -q .owner.login)"; name="$(gh repo view --json name -q .name)"
num="$(jq -r .number "$tmp/view.json")"
gh api graphql -F owner="$owner" -F name="$name" -F num="$num" -f query='
  query($owner:String!,$name:String!,$num:Int!){repository(owner:$owner,name:$name){pullRequest(number:$num){
    reviewThreads(first:100){nodes{isResolved}}}}}' > "$tmp/threads.json"
base="$(jq -r .baseRefName "$tmp/view.json")"
head_owner="$(jq -r '.headRepositoryOwner.login // empty' "$tmp/view.json")"
head="$(jq -r .headRefName "$tmp/view.json")"
gh api "repos/$owner/$name/compare/$base...${head_owner:+$head_owner:}$head" --jq '{behind_by}' > "$tmp/compare.json" 2>/dev/null \
  || echo '{"behind_by":0}' > "$tmp/compare.json"
summarize "$tmp/view.json" "$tmp/threads.json" "$tmp/compare.json"
