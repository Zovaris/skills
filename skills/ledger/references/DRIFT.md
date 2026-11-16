# Keeping docs in sync with code

## 1 · Deterministic checks first

`scripts/drift.sh <base>` reports:
- **Changed files and the docs that mention them** (by path or by exported symbol name): each
  pairing is a doc to re-read.
- **Missing references:** paths and backticked symbols named in docs that no longer exist in the
  code.
- **Public API changes without docs:** changed source files with exported symbols whose doc
  comments or module README didn't change in the same diff.

Then run the stack's doc generator in strict mode when it exists (`typedoc --treatWarningsAsErrors`,
`RUSTDOCFLAGS="-D warnings" cargo doc`, `pdoc --fail-on-warning` or mkdocs `--strict`), and the
comment check: `scripts/comments.sh --diff <base>`.

## 2 · Then judgement

For each flagged doc, read the doc and the diff and decide:
- Still true → leave it.
- Wrong or stale → fix it in this branch (module README, map, glossary, how-to).
- A decision changed → new ADR superseding the old one; never edit the old decision.
- Can't tell from the code → list it for the user; don't guess.

## 3 · Report

List what changed and what is left for the user, with file paths. In a PR body this is the
"Docs updated" section.
