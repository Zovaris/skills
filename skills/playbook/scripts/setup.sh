#!/usr/bin/env bash
# playbook setup: what is installed, model settings, and the agent instructions block.
#   setup.sh status                 installed skills, models for this harness, block presence
#   setup.sh block status [file]    is the block in <file> (default: this harness's user file)?
#   setup.sh block add [file]       add or refresh the block (between playbook:start/end markers)
#   setup.sh block remove [file]    remove it
# Default file per harness: claude-* → ~/.claude/CLAUDE.md, codex → ~/.codex/AGENTS.md,
# opencode → ~/.config/opencode/AGENTS.md, gemini → ~/.gemini/GEMINI.md, else ./AGENTS.md.
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd -P)"
BLOCK="$DIR/../references/AGENTS-BLOCK.md"
harness() { "$DIR/harness.sh" | awk '{print $1}'; }
default_file() {
  case "$(harness)" in
    claude-*) echo "$HOME/.claude/CLAUDE.md" ;; codex) echo "$HOME/.codex/AGENTS.md" ;;
    opencode) echo "$HOME/.config/opencode/AGENTS.md" ;; gemini) echo "$HOME/.gemini/GEMINI.md" ;;
    *) echo "$PWD/AGENTS.md" ;;
  esac
}
has_block() { [ -f "$1" ] && grep -q '<!-- playbook:start -->' "$1"; }
strip() { awk '/<!-- playbook:start -->/{skip=1} !skip{print} /<!-- playbook:end -->/{skip=0}' "$1"; }

case "${1:-}" in
  status)
    echo "harness: $(harness)"
    echo "installed:"; "$DIR/find-skill.sh" --list | awk '{printf "  %-9s %s\n", $1, $2}'
    echo "settings (repo, then user, then default):"; "$DIR/config.sh" list | sed 's/^/  /' 
    f="$(default_file)"; has_block "$f" && echo "block: present in $f" || echo "block: missing in $f (setup.sh block add)"
    ;;
  block)
    f="${3:-$(default_file)}"
    case "${2:-}" in
      status) has_block "$f" && echo "present in $f" || { echo "missing in $f"; exit 1; } ;;
      add)
        mkdir -p "$(dirname "$f")"; touch "$f"
        tmp="$(mktemp)"; strip "$f" > "$tmp"
        { cat "$tmp"; [ -s "$tmp" ] && echo; cat "$BLOCK"; } > "$f"; rm -f "$tmp"
        echo "added to $f" ;;
      remove)
        has_block "$f" || { echo "not in $f"; exit 0; }
        tmp="$(mktemp)"; strip "$f" > "$tmp"; mv "$tmp" "$f"; echo "removed from $f" ;;
      *) echo 'usage: setup.sh block status|add|remove [file]' >&2; exit 2 ;;
    esac ;;
  *) sed -n '2,8p' "$0"; exit 2 ;;
esac
