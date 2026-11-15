#!/usr/bin/env bash
# forge: source files changed against a base, without tests, docs or generated files.
#   changed.sh [base]   (default: merge-base with origin's default branch)
# One path per line; `--csv` as last arg joins them with commas (for Stryker --mutate).
set -euo pipefail
csv=0; [ "${!#:-}" = "--csv" ] && { csv=1; set -- "${@:1:$(($#-1))}"; }
base="${1:-}"
if [ -z "$base" ]; then
  d="$(git symbolic-ref -q --short refs/remotes/origin/HEAD 2>/dev/null || echo origin/main)"
  base="$(git merge-base HEAD "$d")"
fi
files="$( { git diff --name-only --diff-filter=ACMR "$base"...HEAD; git diff --name-only --diff-filter=ACMR; } | sort -u \
  | grep -E '\.(ts|tsx|js|jsx|mjs|cjs|py|rs|go|rb|java|kt|swift)$' \
  | grep -vE '(^|/)(tests?|__tests__|spec|e2e|fixtures|__snapshots__)/|\.(test|spec|adversary|property)\.|(^|/)test_[^/]*\.py$|_test\.(go|py)$|\.d\.ts$|(^|/)(dist|build|generated)/' || true)"
[ $csv -eq 1 ] && echo "$files" | paste -sd, - || echo "$files"
