#!/usr/bin/env bash
# Per-user settings shared by the skills, in ~/.agents/config.json ($AGENTS_CONFIG).
# Models are stored per harness because names differ (haiku, gpt-5-mini, ...); nothing is hard-coded.
#   config.sh model <cheap|strong>         model for this harness; empty + exit 3 when unset
#   config.sh set-model <cheap|strong> <name> [harness]
#   config.sh get <dotted.key>             any value, e.g. playbook.agents_block
#   config.sh set <dotted.key> <value>     value parsed as JSON when it is JSON
# When `model` exits 3, ask the user once ("Which cheap model should scouts and reviewers use
# here?") and save the answer with set-model; until then, use the harness default.
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd -P)"
CFG="${AGENTS_CONFIG:-$HOME/.agents/config.json}"
mkdir -p "$(dirname "$CFG")"; [ -f "$CFG" ] || echo '{}' > "$CFG"
harness() { "$DIR/harness.sh" 2>/dev/null | awk '{print $1}'; }
get() { jq -r --arg k "$1" 'getpath($k | split(".")) // empty' "$CFG"; }
set_() {
  local v="$2" tmp; tmp="$(mktemp)"
  if jq -e . >/dev/null 2>&1 <<<"$v"; then jq --arg k "$1" --argjson v "$v" 'setpath($k | split("."); $v)' "$CFG" > "$tmp"
  else jq --arg k "$1" --arg v "$v" 'setpath($k | split("."); $v)' "$CFG" > "$tmp"; fi
  mv "$tmp" "$CFG"
}
case "${1:-}" in
  model)
    [[ "${2:-}" =~ ^(cheap|strong)$ ]] || { echo 'usage: config.sh model <cheap|strong>' >&2; exit 2; }
    v="$(get "models.$(harness).$2")"; [ -n "$v" ] || exit 3; echo "$v" ;;
  set-model)
    [[ "${2:-}" =~ ^(cheap|strong)$ ]] && [ -n "${3:-}" ] || { echo 'usage: config.sh set-model <cheap|strong> <name> [harness]' >&2; exit 2; }
    set_ "models.${4:-$(harness)}.$2" "$3"; echo "saved models.${4:-$(harness)}.$2 = $3" ;;
  get) [ -n "${2:-}" ] || exit 2; get "$2" ;;
  set) [ -n "${2:-}" ] && [ $# -ge 3 ] || exit 2; set_ "$2" "$3" ;;
  *) sed -n '2,10p' "$0"; exit 2 ;;
esac
