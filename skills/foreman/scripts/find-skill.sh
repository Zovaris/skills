#!/usr/bin/env bash
# foreman: prints the absolute path of an installed skill's SKILL.md, so workers can read and
# follow it directly. User-invoked skills (disable-model-invocation) can't be called by an agent
# as a slash command, but any agent in any harness can read the file.
#   find-skill.sh <name>     exit 1 when not installed
set -euo pipefail
[ $# -eq 1 ] || { echo 'usage: find-skill.sh <name>' >&2; exit 2; }
here="$(cd "$(dirname "$0")/.." && pwd -P)"
for f in "$here/../$1/SKILL.md" ~/.agents/skills/$1/SKILL.md ~/.claude/skills/$1/SKILL.md \
         ~/.codex/skills/$1/SKILL.md ~/.config/opencode/skills/$1/SKILL.md; do
  [ -f "$f" ] && { (cd "$(dirname "$f")" && echo "$(pwd -P)/SKILL.md"); exit 0; }
done
exit 1
