#!/usr/bin/env bash
# Atomic commits in the repo's own message style.
#   commit.sh style                    detected style, rules and recent examples (read before writing messages)
#   commit.sh check "<message>"        exit 1 with the reason if the message breaks the style
#   commit.sh "<message>" <path>...    commit exactly these paths with this message (after check)
# Style: commitlint config > .gitmessage > the last 30 subjects (conventional, gitmoji or plain).
# Atomic means one concern per commit: call it once per group of paths, never `git add -A`.
# Never bypasses hooks; a failing hook fails the commit.
set -euo pipefail
die() { echo "commit.sh: $*" >&2; exit 1; }
git rev-parse --git-dir >/dev/null 2>&1 || die "not a git repo"

subjects() { git log -n 30 --no-merges --format=%s 2>/dev/null || true; }
CONV='^(feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert)(\([a-z0-9._/-]+\))?!?: [^ ]'

detect() {
  local top; top="$(git rev-parse --show-toplevel)"
  if ls "$top"/commitlint.config.* "$top"/.commitlintrc* >/dev/null 2>&1; then echo conventional; return; fi
  local s n conv emoji
  s="$(subjects)"; n=$(grep -c . <<<"$s" || true)
  [ "$n" -eq 0 ] && { echo conventional; return; }
  conv=$(grep -cE "$CONV" <<<"$s" || true)
  emoji=$(grep -cE '^(:[a-z0-9_+-]+:|[^[:print:][:space:]])' <<<"$s" || true)
  if [ $((conv * 2)) -ge "$n" ]; then echo conventional
  elif [ $((emoji * 2)) -ge "$n" ]; then echo gitmoji
  else echo plain; fi
}

check() {
  local msg="$1" style subject; style="$(detect)"; subject="${msg%%$'\n'*}"
  [ -n "$subject" ] || die "empty message"
  [ ${#subject} -le 72 ] || die "subject is ${#subject} chars; keep it ≤ 72"
  [[ "$subject" =~ \.$ ]] && die "subject ends with a period"
  case "$style" in
    conventional) [[ "$subject" =~ $CONV ]] || die "not conventional: '<type>(<scope>): <imperative summary>' (types: feat fix docs style refactor perf test build ci chore revert)" ;;
    gitmoji) grep -qE '^(:[a-z0-9_+-]+:|[^[:print:][:space:]])' <<<"$subject" || die "gitmoji style: start with an emoji or :code:" ;;
  esac
  return 0
}

case "${1:-}" in
  style)
    st="$(detect)"
    echo "style: $st"
    case "$st" in
      conventional) echo "format: <type>(<scope>): <imperative summary, lowercase, no period, ≤72>" ;;
      gitmoji) echo "format: <emoji> <imperative summary, ≤72>" ;;
      plain) echo "format: <Imperative summary, ≤72>, matching the examples below" ;;
    esac
    scopes="$(subjects | grep -oE '^[a-z]+\([a-z0-9._/-]+\)' | sed -E 's/.*\((.*)\)/\1/' | sort | uniq -c | sort -rn | awk '{print $2}' | head -8 | paste -sd' ' -)"
    [ -n "$scopes" ] && echo "scopes in use: $scopes"
    echo "examples:"; subjects | head -5 | sed 's/^/  /'
    ;;
  check) [ $# -eq 2 ] || die 'usage: commit.sh check "<message>"'; check "$2"; echo ok ;;
  ""|-h|--help) sed -n '2,8p' "$0"; exit 2 ;;
  *)
    msg="$1"; shift
    [ $# -ge 1 ] || die "name the paths for this commit (atomic: one concern per commit)"
    check "$msg"
    staged="$(git diff --cached --name-only)"
    [ -z "$staged" ] || die "already staged: $(echo "$staged" | paste -sd' ' -); unstage or include them deliberately"
    git add -- "$@"
    [ -n "$(git diff --cached --name-only)" ] || die "nothing to commit in: $*"
    git commit -q -m "$msg"
    git log -1 --format='%h %s'
    ;;
esac
