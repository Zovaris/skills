#!/usr/bin/env bash
# Settings shared by the skills. Two files, repo first:
#   <repo>/.smithy/config.json   per-repo overrides (set with --repo)
#   ~/.smithy/config.json        the user's defaults ($SMITHY_CONFIG)
# Models are stored per harness (user file only) because names differ; nothing is hard-coded.
#   config.sh model <cheap|mid|strong>          model for this harness; exit 3 when unset
#   config.sh set-model <cheap|mid|strong> <name> [harness]
#   config.sh suggest-models                    `<tier> <model>` suggestions for this harness; exit 3 when none
#   config.sh accept-models                     save the suggestions (only after the user said yes)
#   config.sh get <key>                         effective value (repo, then user, then default); exit 3 when unset with no default
#   config.sh set [--repo] <key> <value>        value parsed as JSON when it is JSON
#   config.sh list                              every known setting: value, source, what it does
#   config.sh migrate                           move pre-0.8 state (~/.agents/{config.json,plans,foreman,tend}) to ~/.smithy
# Unset and no default → ask the user once, then save with `set` (or `set --repo` when the
# answer only applies to this repo).
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd -P)"
USER_CFG="${SMITHY_CONFIG:-${SMITHY_HOME:-$HOME/.smithy}/config.json}"
top="$(git rev-parse --show-toplevel 2>/dev/null || true)"
REPO_CFG="${top:+$top/.smithy/config.json}"
# Before 0.8 the repo file was .agents/config.json: still read it until someone moves it.
[ -n "$top" ] && [ ! -f "$REPO_CFG" ] && [ -f "$top/.agents/config.json" ] && REPO_CFG="$top/.agents/config.json"

migrate() {
  local old="$HOME/.agents" new="${SMITHY_HOME:-$HOME/.smithy}" a b moved=0
  for pair in config.json:config.json plans:plans foreman:warden tend:tend; do
    a="$old/${pair%%:*}"; b="$new/${pair##*:}"
    [ -e "$a" ] && [ ! -e "$b" ] && { mkdir -p "$new"; mv "$a" "$b"; echo "moved $a -> $b"; moved=1; }
  done
  [ $moved -eq 1 ] || echo "nothing to migrate"
}
# One-time, automatic: the first run after upgrading moves the old state (our files only).
[ -z "${SMITHY_CONFIG:-}" ] && [ ! -e "${SMITHY_HOME:-$HOME/.smithy}" ] && [ -f "$HOME/.agents/config.json" ] && migrate >&2

# key | default ("ask" = no default, ask once) | used by | meaning
KNOWN='tasks.location|repo|smelt plan|where task lists live: repo, local (~/.smithy/plans) or board
tasks.commit|ask|smelt plan|commit specs and tasks (docs/specs) or keep them out of git (.docs/specs)
git.branch|{type}/{key}-{slug}|smelt warden|branch name template: {type} feat/fix/docs/refactor/test/chore, {key} ticket or task id, {slug} from the title
git.worktree|{parent}/worktrees/{repo}-{branch}|smelt warden tend|worktree path template ({branch} with / as -)
tasks.ignore|ask|smelt plan|with tasks.commit false: gitignore (commit a .gitignore line) or exclude (local .git/info/exclude)
warden.merge|auto|warden|auto: workers merge green PRs; manual: they stop at ready
warden.cleanup|auto|warden|auto: end finished workers and remove worktrees and local branches without asking
warden.max|3|warden|parallel workers (a token-cost cap)
warden.mode|smelt fast|warden|worker mode: smelt fast, smelt normal, smelt full or plain
warden.worker_model|route|warden|route: pick cheap/mid/strong per task (route.js); session: same model as the parent session; or one model name for every worker
tend.watch|prs|tend|what /tend watch looks at: prs, issues or all
tend.label|agent|tend|label of issues tend may queue for warden'

harness() { "$DIR/harness.sh" 2>/dev/null | awk '{print $1}'; }
read_key() { [ -n "$2" ] && [ -f "$2" ] && jq -r --arg k "$1" 'getpath($k | split(".")) | if . == null then empty else tostring end' "$2" 2>/dev/null || true; }
default_of() { awk -F'|' -v k="$1" '$1 == k {print $2}' <<<"$KNOWN"; }
effective() {
  local v
  v="$(read_key "$1" "$REPO_CFG")"; [ -n "$v" ] && { echo "$v repo"; return; }
  v="$(read_key "$1" "$USER_CFG")"; [ -n "$v" ] && { echo "$v user"; return; }
  v="$(default_of "$1")"; [ -n "$v" ] && [ "$v" != ask ] && { echo "$v default"; return; }
  return 3
}
write() {
  local file="$1" k="$2" v="$3" tmp; mkdir -p "$(dirname "$file")"; [ -f "$file" ] || echo '{}' > "$file"
  tmp="$(mktemp)"
  if jq . >/dev/null 2>&1 <<<"$v"; then jq --arg k "$k" --argjson v "$v" 'setpath($k | split("."); $v)' "$file" > "$tmp"
  else jq --arg k "$k" --arg v "$v" 'setpath($k | split("."); $v)' "$file" > "$tmp"; fi
  mv "$tmp" "$file"
}

case "${1:-}" in
  model)
    [[ "${2:-}" =~ ^(cheap|mid|strong)$ ]] || { echo 'usage: config.sh model <cheap|mid|strong>' >&2; exit 2; }
    v="$(read_key "models.$(harness).$2" "$USER_CFG")"; [ -n "$v" ] || exit 3; echo "$v" ;;
  set-model)
    [[ "${2:-}" =~ ^(cheap|mid|strong)$ ]] && [ -n "${3:-}" ] || { echo 'usage: config.sh set-model <cheap|mid|strong> <name> [harness]' >&2; exit 2; }
    write "$USER_CFG" "models.${4:-$(harness)}.$2" "$3"; echo "saved models.${4:-$(harness)}.$2 = $3 ($USER_CFG)" ;;
  suggest-models)
    # Only where the harness has stable tier aliases; elsewhere model names vary per account and
    # provider, so the user names them.
    case "$(harness)" in
      claude-*) printf 'cheap haiku\nmid sonnet\nstrong opus\n' ;;
      *) exit 3 ;;
    esac ;;
  accept-models)
    sug="$("$0" suggest-models)" || { echo "no suggestions for $(harness): ask the user for each tier" >&2; exit 3; }
    while read -r tier m; do write "$USER_CFG" "models.$(harness).$tier" "$m"; echo "saved models.$(harness).$tier = $m"; done <<<"$sug" ;;
  get)
    [ -n "${2:-}" ] || exit 2
    r="$(effective "$2")" || exit 3; echo "${r% *}" ;;
  set)
    shift; file="$USER_CFG"
    [ "${1:-}" = --repo ] && { [ -n "$REPO_CFG" ] || { echo "not in a git repo" >&2; exit 2; }; file="$REPO_CFG"; shift; }
    [ $# -eq 2 ] || { echo 'usage: config.sh set [--repo] <key> <value>' >&2; exit 2; }
    write "$file" "$1" "$2"; echo "saved $1 = $2 ($file)" ;;
  migrate) migrate ;;
  list)
    h="$(harness)"
    for m in cheap mid strong; do
      v="$(read_key "models.$h.$m" "$USER_CFG")"
      printf '%-16s %-14s %-8s %s\n' "models.$m" "${v:-unset}" "${v:+user}" "$m model in $h"
    done
    while IFS='|' read -r k d who what; do
      r="$(effective "$k" || echo "unset -")"
      printf '%-16s %-14s %-8s %s (used by %s)\n' "$k" "${r% *}" "${r##* }" "$what" "$who"
    done <<<"$KNOWN" ;;
  *) sed -n '2,13p' "$0"; exit 2 ;;
esac
