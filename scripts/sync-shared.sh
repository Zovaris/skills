#!/usr/bin/env bash
# Copies shared/ scripts into each skill that uses them, so every skill installs on its own.
#   scripts/sync-shared.sh          copy
#   scripts/sync-shared.sh --check  exit 1 if any copy differs from shared/ (CI / before commit)
set -euo pipefail
cd "$(dirname "$0")/.."
# skill: shared files it ships
MAP="smelt:consult.sh route.js task-dir.sh agent.sh commit.sh pr.sh cleanup.sh find-skill.sh smithy smithy.cmd VERSION
warden:consult.sh route.js task-dir.sh agent.sh commit.sh pr.sh cleanup.sh find-skill.sh verify.sh smithy smithy.cmd VERSION
use-smithy:find-skill.sh smithy smithy.cmd VERSION
scout:agent.sh smithy smithy.cmd VERSION
tend:consult.sh agent.sh route.js verify.sh commit.sh smithy smithy.cmd VERSION"
check=0; [ "${1:-}" = --check ] && check=1; bad=0
while IFS=: read -r skill files; do
  for f in $files; do
    dst="skills/$skill/scripts/$f"
    if [ $check -eq 1 ]; then cmp -s "shared/$f" "$dst" || { echo "out of sync: $dst"; bad=1; }
    else mkdir -p "$(dirname "$dst")"; cp "shared/$f" "$dst"; chmod +x "$dst"; fi
  done
done <<<"$MAP"
[ $check -eq 1 ] && { [ $bad -eq 0 ] && echo "shared scripts in sync"; exit $bad; }
echo "synced shared/ into skills"
