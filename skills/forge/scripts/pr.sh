#!/usr/bin/env bash
# Pull requests that follow the repo's PR template.
#   pr.sh template                        print the template path(s); exit 1 when the repo has none
#   pr.sh create --base <b> --title "<t>" --body-file <f> [--draft]
#                                         open the PR for the current branch, or print the open one
# With a template, the body must keep every heading of the template (fill them, write "N/A" when
# one doesn't apply). The title follows the commit style (commit.sh check) when commit.sh is next
# to this script.
set -euo pipefail
die() { echo "pr.sh: $*" >&2; exit 1; }
DIR="$(cd "$(dirname "$0")" && pwd -P)"
top="$(git rev-parse --show-toplevel 2>/dev/null)" || die "not a git repo"

templates() {
  local f seen=" "
  for f in .github/pull_request_template.md .github/PULL_REQUEST_TEMPLATE.md docs/pull_request_template.md \
           docs/PULL_REQUEST_TEMPLATE.md pull_request_template.md PULL_REQUEST_TEMPLATE.md; do
    [ -f "$top/$f" ] || continue
    # case-insensitive filesystems resolve both spellings to one file
    local id; id="$(ls -i "$top/$f" | awk '{print $1}')"
    case "$seen" in *" $id "*) continue ;; esac
    seen="$seen$id "; echo "$top/$f"
  done
  [ -d "$top/.github/PULL_REQUEST_TEMPLATE" ] && find "$top/.github/PULL_REQUEST_TEMPLATE" -maxdepth 1 -name '*.md' | sort
  return 0
}

case "${1:-}" in
  template)
    t="$(templates)"; [ -n "$t" ] || exit 1; echo "$t" ;;
  create)
    shift; base=""; title=""; body=""; draft=()
    while [ $# -gt 0 ]; do case "$1" in
      --base) base="$2"; shift 2 ;; --title) title="$2"; shift 2 ;;
      --body-file) body="$2"; shift 2 ;; --draft) draft=(--draft); shift ;;
      *) die "unknown option $1" ;; esac; done
    [ -n "$base" ] && [ -n "$title" ] && [ -f "$body" ] || die 'usage: pr.sh create --base <b> --title "<t>" --body-file <f> [--draft]'
    branch="$(git branch --show-current)"
    open="$(gh pr list --head "$branch" --state open --json url -q '.[0].url' 2>/dev/null || true)"
    [ -n "$open" ] && { echo "$open"; exit 0; }
    [ -x "$DIR/commit.sh" ] && { "$DIR/commit.sh" check "$title" >/dev/null || die "title doesn't follow the commit style: $("$DIR/commit.sh" check "$title" 2>&1)"; }
    t="$(templates | head -1)"
    if [ -n "$t" ]; then
      missing="$(grep -E '^#{1,4} ' "$t" | while IFS= read -r h; do grep -qxF "$h" "$body" || echo "$h"; done)"
      [ -z "$missing" ] || die "body drops template headings from ${t#$top/}: $(echo "$missing" | paste -sd'|' -)"
    fi
    git push -q -u origin "$branch"
    gh pr create --base "$base" --head "$branch" --title "$title" --body-file "$body" ${draft[@]+"${draft[@]}"}
    ;;
  *) sed -n '2,8p' "$0"; exit 2 ;;
esac
