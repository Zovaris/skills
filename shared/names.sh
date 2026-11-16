#!/usr/bin/env bash
# The one place that names branches and worktrees for smelt, warden and tend.
#   names.sh branch <key> <title> [type]   e.g. feat/PROJ-123-add-login, fix/42-null-crash, feat/03-retry-queue
#   names.sh worktree <branch> [repo-dir]  absolute path: <repo-parent>/worktrees/<repo>-<branch with / as ->
#   names.sh type <title>                  feat | fix | docs | refactor | test | chore, from the title
# <key> is the id the task already has: a Jira or Linear key, a GitHub issue number, a task file's
# NN, or "-" for none. Templates come from settings `git.branch` (default `{type}/{key}-{slug}`)
# and `git.worktree` (default `{parent}/worktrees/{repo}-{branch}`); the repo's agent
# instructions win over both.
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd -P)"
setting() { "$DIR/config.sh" get "$1" 2>/dev/null || echo "$2"; }

slug() {
  local s
  s="$(printf '%s' "$1" | iconv -f utf-8 -t ascii//TRANSLIT 2>/dev/null || printf '%s' "$1")"
  s="$(printf '%s' "$s" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+|-+$//g')"
  while [ ${#s} -gt 40 ] && [[ "$s" == *-* ]]; do s="${s%-*}"; done
  printf '%s' "${s:0:40}"
}

type_of() {
  local t
  t="$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')"
  case "$t" in
    fix*|*bug*|*crash*|*broken*|*error*|*regression*) echo fix ;;
    doc*|*readme*|*adr*) echo docs ;;
    refactor*|rename*|extract*|move*|split*) echo refactor ;;
    test*|*coverage*) echo test ;;
    chore*|bump*|upgrade*|*dependenc*|ci*) echo chore ;;
    *) echo feat ;;
  esac
}

case "${1:-}" in
  branch)
    [ $# -ge 3 ] || { echo "usage: names.sh branch <key|-> <title> [type]" >&2; exit 2; }
    key="$2"; [ "$key" = - ] && key=""
    key="$(printf '%s' "$key" | sed -E 's/^#//; s/[^A-Za-z0-9._-]+/-/g')"
    type="${4:-$(type_of "$3")}"; s="$(slug "$3")"; s="${s#"$type"-}"
    b="$(setting git.branch '{type}/{key}-{slug}')"
    b="${b//\{type\}/$type}"; b="${b//\{key\}/$key}"; b="${b//\{slug\}/$s}"
    printf '%s\n' "$b" | sed -E 's#/-#/#; s#-+$##; s#--+#-#g' ;;
  worktree)
    [ $# -ge 2 ] || { echo "usage: names.sh worktree <branch> [repo-dir]" >&2; exit 2; }
    top="$(git -C "${3:-.}" rev-parse --show-toplevel)"
    w="$(setting git.worktree '{parent}/worktrees/{repo}-{branch}')"
    w="${w//\{parent\}/$(dirname "$top")}"; w="${w//\{repo\}/$(basename "$top")}"; w="${w//\{branch\}/${2//\//-}}"
    printf '%s\n' "$w" ;;
  type) type_of "${2:-}" ;;
  *) echo "usage: names.sh branch <key|-> <title> [type] | worktree <branch> [repo-dir] | type <title>" >&2; exit 2 ;;
esac
