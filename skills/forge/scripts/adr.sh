#!/usr/bin/env bash
# forge: creates the next numbered ADR and prints its path.
#   adr.sh "<title>" [adr-dir]   (default docs/adr)
set -euo pipefail
[ $# -ge 1 ] || { echo 'usage: adr.sh "<title>" [adr-dir]' >&2; exit 2; }
dir="${2:-docs/adr}"; mkdir -p "$dir"
last="$(ls "$dir" 2>/dev/null | grep -oE '^[0-9]{4}' | sort -n | tail -1 || true)"
n=$(printf '%04d' $(( 10#${last:-0} + 1 )))
[ -z "$last" ] && n=0001
slug="$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-|-$//g' | cut -c1-60)"
f="$dir/$n-$slug.md"
cat > "$f" <<EOF
# $n · $1
Status: proposed
Date: $(date +%F)

<Context and decision in one or two paragraphs: what forced the choice, what we chose.>
EOF
echo "$f"
