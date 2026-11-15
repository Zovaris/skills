#!/usr/bin/env bash
# docs: searches project docs and decisions, best sources first.
#   search.sh "<query>" [--adr|--glossary|--all] [--max N]
# Order: ADRs (docs/adr) > glossary > module READMEs > other docs (docs/**, README, AGENTS.md,
# CLAUDE.md). Case-insensitive fixed-string match. Prints `file:line: text`, at most N lines
# (default 40). Uses ripgrep when installed, grep otherwise. Exit 1 when nothing matches.
set -uo pipefail
q=""; scope=all; max=40
while [ $# -gt 0 ]; do case "$1" in
  --adr) scope=adr; shift ;; --glossary) scope=glossary; shift ;; --all) scope=all; shift ;;
  --max) max="$2"; shift 2 ;; *) q="$1"; shift ;; esac; done
[ -n "$q" ] || { echo 'usage: search.sh "<query>" [--adr|--glossary|--all] [--max N]' >&2; exit 2; }
root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"; cd "$root"

prune='-path ./.git -o -path ./node_modules -o -path ./vendor -o -path ./dist -o -path ./build -o -path ./target -o -path ./.venv'
adrs() { [ -d docs/adr ] && find docs/adr -name '*.md' | sort; }
glossary() { for f in docs/GLOSSARY.md GLOSSARY.md; do [ -f "$f" ] && echo "$f"; done; return 0; }
modules() { find . \( $prune \) -prune -o -name README.md -print | sed 's#^\./##' | grep -v -e '^README.md$' -e '^docs/' | sort; }
others() {
  { [ -d docs ] && find docs -name '*.md' -not -path 'docs/adr/*' -not -name GLOSSARY.md
    for f in README.md AGENTS.md CLAUDE.md; do [ -f "$f" ] && echo "$f"; done; } | sort -u
}
hit() {
  [ $# -gt 0 ] || return 0
  if command -v rg >/dev/null 2>&1; then rg -n -i -F --no-heading --with-filename --sort path -- "$q" "$@" 2>/dev/null
  else grep -n -i -F -H -- "$q" "$@" 2>/dev/null; fi
}
files() { local l; l="$("$1")"; [ -n "$l" ] && echo "$l"; return 0; }

run() {
  case "$scope" in
    adr) hit $(files adrs) ;;
    glossary) hit $(files glossary) ;;
    *) hit $(files adrs); hit $(files glossary); hit $(files modules); hit $(files others) ;;
  esac
}
out="$(run)"
[ -n "$out" ] || { echo "no match for \"$q\"" >&2; exit 1; }
total=$(grep -c . <<<"$out")
cut -c1-220 <<<"$out" | head -n "$max"
[ "$total" -gt "$max" ] && echo "… $((total - max)) more (narrow the query or use --adr/--glossary)"
exit 0
