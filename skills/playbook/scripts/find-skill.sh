#!/usr/bin/env bash
# Finds installed skills, so a skill or a worker can read another skill's SKILL.md directly.
# User-invoked skills can't be called by an agent as a slash command, but any agent in any
# harness can read the file.
#   find-skill.sh <name>     absolute path of <name>/SKILL.md; exit 1 when not installed
#   find-skill.sh --list     `<name> <path>` for every skill of this repo that is installed
set -euo pipefail
here="$(cd "$(dirname "$0")/.." && pwd -P)"
KNOWN="playbook forge foreman docs scout tend silent direct"
find_one() {
  local f
  for f in "$here/../$1/SKILL.md" ~/.agents/skills/$1/SKILL.md ~/.claude/skills/$1/SKILL.md \
           ~/.codex/skills/$1/SKILL.md ~/.config/opencode/skills/$1/SKILL.md; do
    [ -f "$f" ] && { (cd "$(dirname "$f")" && echo "$(pwd -P)/SKILL.md"); return 0; }
  done
  return 1
}
case "${1:-}" in
  --list) for s in $KNOWN; do p="$(find_one "$s")" && echo "$s $p"; done; exit 0 ;;
  ""|-h|--help) sed -n '2,7p' "$0"; exit 2 ;;
  *) find_one "$1" || exit 1 ;;
esac
