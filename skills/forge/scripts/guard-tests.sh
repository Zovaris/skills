#!/usr/bin/env bash
# forge: PreToolUse hook that blocks edits to test files during the green phase of TDD.
# Active only while `.forge/green` exists in the project root; otherwise it allows everything.
#
# Install as a pre-edit hook in any harness that supports one. Claude Code (.claude/settings.json):
#   "hooks": { "PreToolUse": [ { "matcher": "Edit|Write|MultiEdit",
#     "hooks": [ { "type": "command", "command": "<skill-dir>/scripts/guard-tests.sh" } ] } ] }
# Add `.forge/` to .gitignore.
input="$(cat)"
root="$(jq -r '.cwd // empty' <<<"$input")"; root="${root:-$PWD}"
top="$(git -C "$root" rev-parse --show-toplevel 2>/dev/null || echo "$root")"
[ -f "$top/.forge/green" ] || exit 0
path="$(jq -r '.tool_input.file_path // empty' <<<"$input")"
if [[ "$path" =~ (^|/)(tests?|__tests__|spec|e2e)/ || "$path" =~ \.(test|spec|adversary|property)\.[a-z]+$ \
   || "$path" =~ (^|/)test_[^/]*\.py$ || "$path" =~ _test\.(go|py)$ || "$path" =~ __snapshots__/ ]]; then
  echo "forge: green phase — tests are read-only. If this test contradicts the spec, stop and say so; remove .forge/green to start the next red step." >&2
  exit 2
fi
exit 0
