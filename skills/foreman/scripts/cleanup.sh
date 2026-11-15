#!/usr/bin/env bash
# Removes a finished task's worktree and local branch, so nothing piles up.
#   cleanup.sh <repo> <branch> [<worktree>] [--force]
# - Worktree: removed (refuses if it has uncommitted changes, unless --force).
# - Local branch: deleted when it is merged, or its commits are all on a remote branch (pushed),
#   or --force. Unpushed work is never thrown away silently: it refuses and says so.
# - Remote branches are left alone (the PR / host decides).
# Prints one line: `cleaned <branch>` or `kept <branch>: <why>`; exit 1 when something was kept.
set -uo pipefail
[ $# -ge 2 ] || { echo 'usage: cleanup.sh <repo> <branch> [<worktree>] [--force]' >&2; exit 2; }
repo="$1"; branch="$2"; wt=""; force=0
shift 2
for a in "$@"; do [ "$a" = --force ] && force=1 || wt="$a"; done
cd "$repo" || exit 2
git fetch -q --prune origin 2>/dev/null || true

[ -z "$wt" ] && wt="$(git worktree list --porcelain | awk -v b="refs/heads/$branch" '/^worktree /{w=$2} $0=="branch " b {print w}')"
if [ -n "$wt" ] && [ -d "$wt" ]; then
  if [ $force -eq 0 ] && [ -n "$(git -C "$wt" status --porcelain 2>/dev/null)" ]; then
    echo "kept $branch: uncommitted changes in $wt"; exit 1
  fi
  args=(); [ $force -eq 1 ] && args=(--force)
  git worktree remove ${args[@]+"${args[@]}"} "$wt" 2>/dev/null || { echo "kept $branch: could not remove $wt"; exit 1; }
fi
git worktree prune

git show-ref -q --verify "refs/heads/$branch" || { echo "cleaned $branch"; exit 0; }
[ "$(git branch --show-current)" = "$branch" ] && { echo "kept $branch: it is checked out here"; exit 1; }
base="$(git symbolic-ref -q --short refs/remotes/origin/HEAD 2>/dev/null || echo origin/main)"
unpushed="$(git rev-list "$branch" --not --remotes 2>/dev/null | head -1)"
if [ $force -eq 1 ] || git merge-base --is-ancestor "$branch" "$base" 2>/dev/null || [ -z "$unpushed" ]; then
  git branch -D "$branch" >/dev/null && echo "cleaned $branch" && exit 0
fi
echo "kept $branch: has commits not on any remote; push it or pass --force"
exit 1
