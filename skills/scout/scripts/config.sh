#!/usr/bin/env bash
# Settings shared by the skills. Two files, repo first:
#   <repo>/.agents/config.json   per-repo overrides (set with --repo)
#   ~/.agents/config.json        the user's defaults ($AGENTS_CONFIG)
# Models are stored per harness (user file only) because names differ; nothing is hard-coded.
#   config.sh model <cheap|strong>              model for this harness; exit 3 when unset
#   config.sh set-model <cheap|strong> <name> [harness]
#   config.sh get <key>                         effective value (repo, then user, then default); exit 3 when unset with no default
#   config.sh set [--repo] <key> <value>        value parsed as JSON when it is JSON
#   config.sh list                              every known setting: value, source, what it does
# Unset and no default → ask the user once, then save with `set` (or `set --repo` when the
# answer only applies to this repo).
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd -P)"
USER_CFG="${AGENTS_CONFIG:-$HOME/.agents/config.json}"
top="$(git rev-parse --show-toplevel 2>/dev/null || true)"
REPO_CFG="${top:+$top/.agents/config.json}"

# key | default ("ask" = no default, ask once) | used by | meaning
KNOWN='tasks.location|repo|forge plan|where task lists live: repo, local (~/.agents/plans) or board
tasks.commit|ask|forge plan|commit specs and tasks (docs/specs) or keep them out of git (.docs/specs)
tasks.ignore|ask|forge plan|with tasks.commit false: gitignore (commit a .gitignore line) or exclude (local .git/info/exclude)
foreman.merge|auto|foreman|auto: workers merge green PRs; manual: they stop at ready
foreman.cleanup|auto|foreman|auto: end finished workers and remove worktrees and local branches without asking
foreman.max|3|foreman|parallel workers (a token-cost cap)
foreman.mode|forge fast|foreman|worker mode: forge fast, forge normal, forge full or plain
tend.watch|prs|tend|what /tend watch looks at: prs, issues or all
tend.label|agent|tend|label of issues tend may queue for foreman'

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
    [[ "${2:-}" =~ ^(cheap|strong)$ ]] || { echo 'usage: config.sh model <cheap|strong>' >&2; exit 2; }
    v="$(read_key "models.$(harness).$2" "$USER_CFG")"; [ -n "$v" ] || exit 3; echo "$v" ;;
  set-model)
    [[ "${2:-}" =~ ^(cheap|strong)$ ]] && [ -n "${3:-}" ] || { echo 'usage: config.sh set-model <cheap|strong> <name> [harness]' >&2; exit 2; }
    write "$USER_CFG" "models.${4:-$(harness)}.$2" "$3"; echo "saved models.${4:-$(harness)}.$2 = $3 ($USER_CFG)" ;;
  get)
    [ -n "${2:-}" ] || exit 2
    r="$(effective "$2")" || exit 3; echo "${r% *}" ;;
  set)
    shift; file="$USER_CFG"
    [ "${1:-}" = --repo ] && { [ -n "$REPO_CFG" ] || { echo "not in a git repo" >&2; exit 2; }; file="$REPO_CFG"; shift; }
    [ $# -eq 2 ] || { echo 'usage: config.sh set [--repo] <key> <value>' >&2; exit 2; }
    write "$file" "$1" "$2"; echo "saved $1 = $2 ($file)" ;;
  list)
    h="$(harness)"
    for m in cheap strong; do
      v="$(read_key "models.$h.$m" "$USER_CFG")"
      printf '%-16s %-14s %-8s %s\n' "models.$m" "${v:-unset}" "${v:+user}" "$m model in $h"
    done
    while IFS='|' read -r k d who what; do
      r="$(effective "$k" || echo "unset -")"
      printf '%-16s %-14s %-8s %s (used by %s)\n' "$k" "${r% *}" "${r##* }" "$what" "$who"
    done <<<"$KNOWN" ;;
  *) sed -n '2,13p' "$0"; exit 2 ;;
esac
