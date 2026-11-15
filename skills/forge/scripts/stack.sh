#!/usr/bin/env bash
# forge: detects the repo's test tooling so agents don't guess. Read-only.
#   stack.sh [repo-dir]
# Prints `key: value` lines; a missing tool prints `key: none`.
set -uo pipefail
cd "${1:-.}" || exit 2
has() { command -v "$1" >/dev/null 2>&1; }
pjson() { [ -f package.json ] && jq -r "$1 // empty" package.json 2>/dev/null; }
dep() { [ -f package.json ] && jq -e --arg d "$1" '(.dependencies // {})[$d] // (.devDependencies // {})[$d]' package.json >/dev/null 2>&1; }
pydep() { grep -qiE "^[^#]*\b$1\b" pyproject.toml requirements*.txt setup.cfg 2>/dev/null; }
out() { printf '%-12s %s\n' "$1:" "${2:-none}"; }

pm=npm
[ -f pnpm-lock.yaml ] && pm=pnpm; [ -f yarn.lock ] && pm=yarn; [ -f bun.lockb ] || [ -f bun.lock ] && pm=bun

langs=()
[ -f package.json ] && langs+=(js)
[ -f tsconfig.json ] && langs+=(ts)
{ [ -f pyproject.toml ] || ls requirements*.txt >/dev/null 2>&1 || [ -f setup.py ]; } && langs+=(python)
[ -f Cargo.toml ] && langs+=(rust)
[ -f go.mod ] && langs+=(go)
out lang "${langs[*]:-unknown}"

test="" single="" typecheck="" lint="" e2e="" mutation="" pbt="" cov="" dev=""
if [ -f package.json ]; then
  out pkg-manager "$pm"
  [ -n "$(pjson .scripts.test)" ] && test="$pm test"
  if dep vitest; then single="npx vitest run <file>"; cov="npx vitest run --coverage --changed"
  elif dep jest; then single="npx jest <file>"; cov="npx jest --coverage --changedSince=<base>"; fi
  [ -n "$(pjson .scripts.typecheck)" ] && typecheck="$pm run typecheck" || { [ -f tsconfig.json ] && typecheck="npx tsc --noEmit"; }
  [ -n "$(pjson .scripts.lint)" ] && lint="$pm run lint"
  [ -n "$(pjson .scripts.dev)" ] && dev="$pm run dev"
  dep @playwright/test && e2e="npx playwright test"
  dep @stryker-mutator/core && mutation="npx stryker run --mutate <files> --incremental"
  dep fast-check && pbt="fast-check"
fi
if [[ " ${langs[*]:-} " == *" python "* ]]; then
  r=""; [ -f uv.lock ] && r="uv run "; [ -f poetry.lock ] && r="poetry run "
  [ -z "$test" ] && test="${r}pytest -q"; [ -z "$single" ] && single="${r}pytest -q <file>"
  pydep mypy && typecheck="${typecheck:+$typecheck; }${r}mypy ."
  pydep pyright && typecheck="${typecheck:+$typecheck; }${r}pyright"
  pydep ruff && lint="${lint:+$lint; }${r}ruff check ."
  pydep pytest-playwright && e2e="${e2e:-${r}pytest -q <e2e dir>}"
  pydep mutmut && mutation="${mutation:-${r}mutmut run --paths-to-mutate <files>}"
  pydep cosmic-ray && mutation="${mutation:-${r}cosmic-ray (see its config)}"
  pydep hypothesis && pbt="${pbt:+$pbt, }hypothesis"
  pydep diff-cover && cov="${cov:-${r}pytest --cov --cov-report=xml && diff-cover coverage.xml --compare-branch=<base>}"
fi
if [ -f Cargo.toml ]; then
  test="${test:-cargo test}"; single="${single:-cargo test <name>}"; typecheck="${typecheck:-cargo check}"; lint="${lint:-cargo clippy}"
  has cargo-mutants && mutation="${mutation:-cargo mutants --in-diff <diff-file>}"
  grep -q proptest Cargo.toml && pbt="${pbt:-proptest}"
fi
if [ -f go.mod ]; then
  test="${test:-go test ./...}"; single="${single:-go test ./<pkg> -run <Name>}"; typecheck="${typecheck:-go vet ./...}"
  pbt="${pbt:-go fuzz (go test -fuzz)}"
fi

out test "$test"; out single "$single"; out typecheck "$typecheck"; out lint "$lint"
out e2e "$e2e"; out mutation "$mutation"; out property "$pbt"; out coverage "$cov"; out dev "$dev"
b="$(git symbolic-ref -q --short refs/remotes/origin/HEAD 2>/dev/null)"; out base "${b#origin/}"
for f in AGENTS.md CLAUDE.md docs/GLOSSARY.md docs/agents/STANDARDS.md; do [ -f "$f" ] && out doc "$f"; done
[ -d docs/adr ] && out adrs "$(ls docs/adr | grep -c '\.md$')"
exit 0
