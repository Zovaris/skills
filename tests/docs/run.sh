#!/usr/bin/env bash
# Tests for skills/docs/scripts: adr numbering, search ranking, comment policy, drift report.
#   tests/docs/run.sh      exit 0 when every assertion passes
set -uo pipefail
S="$(cd "$(dirname "$0")/../../skills/docs/scripts" && pwd -P)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
pass=0; fail=0
ok()   { pass=$((pass+1)); }
bad()  { fail=$((fail+1)); echo "FAIL: $*"; }
has()  { grep -qF -- "$2" <<<"$1" && ok || bad "$3 (missing: $2)"; }
hasnt(){ grep -qF -- "$2" <<<"$1" && bad "$3 (unexpected: $2)" || ok; }

cd "$T" && git init -q repo && cd repo
git config user.email t@t.t && git config user.name t
git commit -q --allow-empty -m init

# adr.sh
a1="$("$S/adr.sh" "Use Postgres for events")"; a2="$("$S/adr.sh" "Second decision")"
[ "$a1" = "docs/adr/0001-use-postgres-for-events.md" ] && ok || bad "first adr path: $a1"
[ "$a2" = "docs/adr/0002-second-decision.md" ] && ok || bad "second adr path: $a2"
has "$(cat "$a1")" "## Decision Outcome" "adr has MADR headings"
has "$(cat "$a1")" "- Status: proposed" "adr starts proposed"
touch docs/adr/0000-record-architecture-decisions.md
a3="$("$S/adr.sh" "Third")"; [ "$a3" = "docs/adr/0003-third.md" ] && ok || bad "numbering after 0000: $a3"
"$S/adr.sh" "" >/dev/null 2>&1 && bad "empty title accepted" || ok

# search.sh ranking: ADR > glossary > module README > other docs
mkdir -p src/billing docs/how-to
printf '# Glossary\n\n**Invoice** — a bill sent to a customer.\n' > docs/GLOSSARY.md
printf '# billing\nInvoice totals are computed here.\n' > src/billing/README.md
printf '# How to\nRegenerate an invoice.\n' > docs/how-to/regen.md
printf '\nWe store every invoice event.\n' >> "$a1"
out="$("$S/search.sh" invoice)"
first="$(head -1 <<<"$out")"; second="$(sed -n 2p <<<"$out")"; third="$(sed -n 3p <<<"$out")"; fourth="$(sed -n 4p <<<"$out")"
[[ "$first" == docs/adr/* ]] && ok || bad "search rank 1 should be an ADR: $first"
[[ "$second" == docs/GLOSSARY.md* ]] && ok || bad "search rank 2 should be glossary: $second"
[[ "$third" == src/billing/README.md* ]] && ok || bad "search rank 3 should be module README: $third"
[[ "$fourth" == docs/how-to/* ]] && ok || bad "search rank 4 should be other docs: $fourth"
out="$("$S/search.sh" invoice --adr)"; hasnt "$out" "GLOSSARY" "--adr limits to ADRs"
"$S/search.sh" zzznomatch >/dev/null 2>&1 && bad "no-match should exit 1" || ok

# comments.sh: allowed cases produce nothing
mkdir -p ok bad
cat > ok/a.ts <<'EOF'
// SPDX-License-Identifier: MIT
/** Adds two numbers. */
export function add(a: number, b: number): number {
  // eslint-disable-next-line no-console -- debug output is part of the CLI contract
  console.log("http://example.com // not a comment");
  // @ts-expect-error legacy types are wrong for this call
  return a + b;
}
EOF
cat > ok/a.py <<'EOF'
#!/usr/bin/env python3
"""Module docstring."""
import os  # noqa: F401 re-exported for plugins
x = "a # not a comment"
y = foo()  # type: ignore[attr-defined]
EOF
cat > ok/a.go <<'EOF'
//go:build linux

// Package a does things.
package a

// Add returns the sum.
func Add(a, b int) int { return a + b } //nolint:revive // name kept for API compatibility
EOF
cat > ok/a.rs <<'EOF'
//! Crate docs.
/// Adds.
pub fn add(a: i32) -> i32 {
    // SAFETY: pointer is valid for the whole call
    unsafe { a }
}
EOF
cat > ok/a.sh <<'EOF'
#!/usr/bin/env bash
# tool: does a thing.
#   tool.sh <arg>
set -e
echo "${PATH#/usr}"
# shellcheck disable=SC2086
echo $x
EOF
out="$("$S/comments.sh" ok 2>&1)"; rc=$?
[ $rc -eq 0 ] && ok || bad "allowed comments flagged: $out"

# comments.sh: forbidden cases each produce a finding
cat > bad/b.ts <<'EOF'
export function sub(a: number, b: number) {
  // subtract because the API wants deltas
  const d = a - b; // keep it signed
  /* old version */
  // return a + b;
  // TODO: handle overflow
  // eslint-disable-next-line no-console
  // @ts-ignore
  return d;
}
EOF
cat > bad/b.py <<'EOF'
def f():
    # explain the loop
    x = 1  # trailing note
    # FIXME later
    y = g()  # noqa
    return x
EOF
cat > bad/b.go <<'EOF'
package b

func helper() int {
	// internal note
	return 1 //nolint:revive
}
EOF
cat > bad/b.sh <<'EOF'
#!/usr/bin/env bash
set -e
# explain this step
echo hi
EOF
out="$("$S/comments.sh" bad 2>&1)"; rc=$?
[ $rc -eq 1 ] && ok || bad "forbidden comments should exit 1"
for want in "bad/b.ts:2: explanatory comment" "bad/b.ts:3: trailing" "bad/b.ts:4: block comment" \
            "bad/b.ts:5: commented-out code" "bad/b.ts:6: TODO/FIXME" "bad/b.ts:7: directive without a reason" \
            "bad/b.ts:8: @ts-ignore" "bad/b.py:2: explanatory comment" "bad/b.py:3: trailing" \
            "bad/b.py:4: TODO/FIXME" "bad/b.py:5: bare noqa" "bad/b.go:4: explanatory comment" \
            "bad/b.go:5: directive without a reason" "bad/b.sh:3: explanatory comment"; do
  has "$out" "$want" "comments.sh finding"
done

# comments.sh --diff only checks changed files
git add -A && git commit -q -m "add files"
printf '\n// new note\n' >> ok/a.ts
out="$("$S/comments.sh" --diff HEAD 2>&1)"
has "$out" "ok/a.ts:10: explanatory comment" "--diff finds the new comment"
hasnt "$out" "bad/b.py" "--diff ignores unchanged files"
git checkout -q ok/a.ts

# drift.sh
cat > src/billing/invoice.ts <<'EOF'
/** Total of an invoice. */
export function invoiceTotal(lines: number[]): number { return lines.reduce((a, b) => a + b, 0); }
EOF
printf '# billing\nSee `src/billing/invoice.ts` and `invoiceTotal()`. Old: `src/billing/gone.ts`, `removedFn()`.\n' > src/billing/README.md
git add -A && git commit -q -m "billing docs"
base="$(git rev-parse HEAD)"
cat >> src/billing/invoice.ts <<'EOF'
export function invoiceTax(total: number): number { return total * 0.2; }
EOF
git add -A && git commit -q -m "tax"
out="$("$S/drift.sh" "$base")"; rc=$?
[ $rc -eq 0 ] && ok || bad "drift.sh should exit 0"
has "$out" "- src/billing/invoice.ts" "drift lists the changed file"
has "$out" "src/billing/README.md (" "drift pairs it with the module README"
has "$out" 'path `src/billing/gone.ts`' "drift reports a missing path"
has "$out" 'symbol `removedFn()`' "drift reports a missing symbol"
hasnt "$out" 'symbol `invoiceTotal()`' "drift keeps existing symbols"
has "$out" "src/billing/invoice.ts: invoiceTax" "drift flags new public API without docs"

echo "docs tests: $pass passed, $fail failed"
[ $fail -eq 0 ]
