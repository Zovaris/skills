#!/usr/bin/env bash
# Copies shared/ scripts into each skill that uses them, so every skill installs on its own.
#   scripts/sync-shared.sh          copy
#   scripts/sync-shared.sh --check  exit 1 if any copy differs from shared/ (CI / before commit)
set -euo pipefail
cd "$(dirname "$0")/.."
# skill: shared files it ships
MAP="forge:agent.sh tasks.js commit.sh pr.sh cleanup.sh
foreman:agent.sh tasks.js commit.sh pr.sh cleanup.sh"
check=0; [ "${1:-}" = --check ] && check=1; bad=0
while IFS=: read -r skill files; do
  for f in $files; do
    dst="skills/$skill/scripts/$f"
    if [ $check -eq 1 ]; then cmp -s "shared/$f" "$dst" || { echo "out of sync: $dst"; bad=1; }
    else cp "shared/$f" "$dst"; chmod +x "$dst"; fi
  done
done <<<"$MAP"
[ $check -eq 1 ] && { [ $bad -eq 0 ] && echo "shared scripts in sync"; exit $bad; }
echo "synced shared/ into skills"
