#!/usr/bin/env bash
# Finds installed skills, so a skill or a worker can read another skill's SKILL.md directly.
# User-invoked skills can't be called by an agent as a slash command, but any agent in any
# harness can read the file.
#   find-skill.sh <name>     absolute path of <name>/SKILL.md; exit 1 when not installed
#   find-skill.sh --list     `<name> <path>` for every skill of this repo that is installed
set -euo pipefail
here="$(cd "$(dirname "$0")/.." && pwd -P)"
KNOWN="use-smithy smelt warden ledger scout tend hush simple"
find_one() {
  local f
  local top; top="$(git rev-parse --show-toplevel 2>/dev/null || true)"
  for f in "$here/../$1/SKILL.md" ${top:+"$top/.agents/skills/$1/SKILL.md" "$top/.claude/skills/$1/SKILL.md"} \
           ~/.agents/skills/$1/SKILL.md ~/.claude/skills/$1/SKILL.md ~/.codex/skills/$1/SKILL.md \
           "${XDG_CONFIG_HOME:-$HOME/.config}/opencode/skills/$1/SKILL.md" ~/.gemini/skills/$1/SKILL.md \
           ~/.cursor/skills/$1/SKILL.md "${PI_CODING_AGENT_DIR:-$HOME/.pi/agent}/skills/$1/SKILL.md" \
           "${DSH_HOME:-$HOME/.dsh}/skills/$1/SKILL.md"; do
    [ -f "$f" ] && { (cd "$(dirname "$f")" && echo "$(pwd -P)/SKILL.md"); return 0; }
  done
  return 1
}
case "${1:-}" in
  --list) for s in $KNOWN; do p="$(find_one "$s")" && echo "$s $p"; done; exit 0 ;;
  ""|-h|--help) sed -n '2,7p' "$0"; exit 2 ;;
  *) find_one "$1" || exit 1 ;;
esac
