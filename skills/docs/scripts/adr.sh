#!/usr/bin/env bash
# docs: creates the next numbered ADR (MADR-compatible headings) and prints its path.
#   adr.sh "<title>" [adr-dir]      (default docs/adr)
# Numbers are never reused; 0000 is reserved for "record architecture decisions" (docs init).
set -euo pipefail
[ $# -ge 1 ] && [ -n "$1" ] || { echo 'usage: adr.sh "<title>" [adr-dir]' >&2; exit 2; }
dir="${2:-docs/adr}"; mkdir -p "$dir"
last="$(ls "$dir" 2>/dev/null | grep -oE '^[0-9]{4}' | sort -n | tail -1 || true)"
n=$(printf '%04d' $(( 10#${last:-0} + 1 )))
slug="$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-|-$//g' | cut -c1-60)"
[ -n "$slug" ] || { echo "adr.sh: title has no letters or digits" >&2; exit 2; }
f="$dir/$n-$slug.md"
cat > "$f" <<EOF
# $n · $1

- Status: proposed
- Date: $(date +%F)

## Context and Problem Statement

<What forced a decision, in one or two paragraphs.>

## Considered Options

- <option> — <why not>

## Decision Outcome

Chosen option: "<option>", because <reason>.

## Consequences

- Good: <what gets easier>
- Bad: <what gets harder>
EOF
echo "$f"
