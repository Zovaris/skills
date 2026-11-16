#!/usr/bin/env bash
# tend: zero-token wait for new or changed PRs / issues. Blocks until something changes, prints
# the changed items, and exits, so the tend session wakes only when there is work.
#   watch.sh [prs|issues|all] [--label <l>] [--every <sec>] [--max-min <min>]
# Prints one line per change: `pr <number> <url>` or `issue <number> <url>`; exit 0 on change,
# 4 on heartbeat (nothing changed within --max-min, default 50). Run it in the background where
# the harness can wake on exit, else in the foreground.
# PRs: open PRs by the user, on foreman/ or tend/ branches, or with --label. Issues: open issues
# with --label (default `agent`). Seen state: ~/.agents/tend/<owner-repo>-<scope>.json ($TEND_HOME).
set -uo pipefail
scope="prs"; label=""; every=120; max=50
case "${1:-}" in prs|issues|all) scope="$1"; shift ;; esac
while [ $# -gt 0 ]; do case "$1" in
  --label) label="$2"; shift 2 ;; --every) every="$2"; shift 2 ;; --max-min) max="$2"; shift 2 ;;
  *) echo "unknown option $1" >&2; exit 2 ;; esac; done
repo="$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null)" || { echo "not a GitHub repo" >&2; exit 2; }
me="$(gh api user -q .login 2>/dev/null || true)"
state="${TEND_HOME:-$HOME/.agents/tend}/${repo//\//-}-$scope.json"; mkdir -p "$(dirname "$state")"

snapshot() {
  local out="[]"
  if [ "$scope" != issues ]; then
    out="$(gh pr list --state open --limit 100 --json number,url,headRefName,author,labels,updatedAt \
      | jq --arg me "$me" --arg l "$label" '[.[] | select(.author.login == $me or (.headRefName | test("^(foreman|tend)/")) or ($l != "" and any(.labels[]?; .name == $l)))
        | {kind: "pr", number, url, v: .updatedAt}]')"
  fi
  if [ "$scope" != prs ]; then
    out="$(jq -s 'add' <(echo "$out") <(gh issue list --state open --limit 100 --label "${label:-agent}" --json number,url,updatedAt \
      | jq '[.[] | {kind: "issue", number, url, v: .updatedAt}]'))"
  fi
  echo "$out"
}
changes() { jq -r -n --argjson old "$1" --argjson new "$2" \
  '$new[] | . as $n | select(([$old[] | select(.kind == $n.kind and .number == $n.number and .v == $n.v)] | length) == 0) | "\(.kind) \(.number) \(.url)"'; }

[ -f "$state" ] || snapshot > "$state"
end=$(( $(date +%s) + max * 60 ))
while [ "$(date +%s)" -lt "$end" ]; do
  now="$(snapshot)" || { sleep "$every"; continue; }
  diff="$(changes "$(cat "$state")" "$now")"
  if [ -n "$diff" ]; then echo "$now" > "$state"; echo "$diff"; exit 0; fi
  sleep "$every"
done
echo "heartbeat: no change in ${max}m"; exit 4
