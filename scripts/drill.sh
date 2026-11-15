#!/usr/bin/env bash
# Pressure-tests skills against a real agent CLI (costs tokens; not run in CI).
#   scripts/drill.sh [scenario...]     default: every tests/drill/*.md
# A scenario file has a `Prompt:` block and `Expect:` / `Reject:` lines (case-insensitive
# substrings of the agent's reply). It runs through agent.sh, so AGENT_CMD / the installed CLI
# decides the harness: run it once per harness you support.
set -uo pipefail
cd "$(dirname "$0")/.."
AGENT="shared/agent.sh"; pass=0; fail=0
for f in "${@:-tests/drill/*.md}"; do
  for sc in $f; do
    p="$(mktemp)"; awk '/^Prompt:/{on=1;next} /^(Expect|Reject):/{on=0} on' "$sc" > "$p"
    out="$("$AGENT" --readonly "$p" 2>&1)"; ok=1
    while IFS= read -r e; do grep -qiF -- "$e" <<<"$out" || { ok=0; echo "  missing: $e"; }; done < <(sed -n 's/^Expect: //p' "$sc")
    while IFS= read -r r; do grep -qiF -- "$r" <<<"$out" && { ok=0; echo "  rejected: $r"; }; done < <(sed -n 's/^Reject: //p' "$sc")
    [ $ok -eq 1 ] && { pass=$((pass+1)); echo "ok   $sc"; } || { fail=$((fail+1)); echo "FAIL $sc"; }
    rm -f "$p"
  done
done
echo "drill: $pass passed, $fail failed"; [ $fail -eq 0 ]
