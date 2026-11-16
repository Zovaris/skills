#!/usr/bin/env bash
# Resolves (and creates) the task dir for a new plan from the user's settings, so forge and
# foreman put specs and tasks in the same place.
#   task-dir.sh <slug>
# Prints the absolute dir. Exit 3 with `ask <key>: <question>` when a setting it needs is unset:
# ask the user, save it (`config.sh set --repo <key> <value>`), run it again.
#   tasks.location  repo (default) | local | board
#   tasks.commit    true: docs/specs/<slug> (committed) · false: .docs/specs/<slug> (kept out of git)
#   tasks.ignore    with commit false — gitignore: add `.docs/` to .gitignore (commit that line
#                   yourself) · exclude: add it to .git/info/exclude (local only, nothing committed)
# Board: prints `board` (the spec still goes to the repo or local dir chosen by tasks.commit).
set -uo pipefail
DIR="$(cd "$(dirname "$0")" && pwd -P)"
[ $# -eq 1 ] || { echo 'usage: task-dir.sh <slug>' >&2; exit 2; }
slug="$1"; cfg="$DIR/config.sh"
top="$(git rev-parse --show-toplevel 2>/dev/null)" || { echo "not a git repo" >&2; exit 2; }
loc="$("$cfg" get tasks.location 2>/dev/null || echo repo)"
if [ "$loc" = local ]; then
  d="${FORGE_PLANS:-$HOME/.agents/plans}/$(basename "$top")/$slug"; mkdir -p "$d"; echo "$d"; exit 0
fi
commit="$("$cfg" get tasks.commit 2>/dev/null)" || { echo "ask tasks.commit: commit the specs and tasks to git (docs/specs), or keep them out of git (.docs/specs)?"; exit 3; }
if [ "$commit" = true ]; then
  d="$top/docs/specs/$slug"
else
  ignore="$("$cfg" get tasks.ignore 2>/dev/null)" || { echo "ask tasks.ignore: keep .docs/ out of git with a committed .gitignore line (gitignore), or only on this machine via .git/info/exclude (exclude)?"; exit 3; }
  if [ "$ignore" = gitignore ]; then f="$top/.gitignore"; else f="$(git rev-parse --git-path info/exclude)"; mkdir -p "$(dirname "$f")"; fi
  if ! grep -qxF '.docs/' "$f" 2>/dev/null; then
    [ -s "$f" ] && [ -n "$(tail -c1 "$f")" ] && printf '\n' >> "$f"
    printf '.docs/\n' >> "$f"
  fi
  d="$top/.docs/specs/$slug"
fi
mkdir -p "$d"
[ "$loc" = board ] && echo "board $d" || echo "$d"
