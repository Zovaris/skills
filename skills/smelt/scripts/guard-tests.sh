#!/usr/bin/env bash
# smelt: blocks edits to test files during the green phase of TDD.
# Active only while `.smelt/green` exists in the project root; otherwise it allows everything.
#
#   guard-tests.sh <file-path>      generic: exit 2 + message if the path is a protected test file
#   guard-tests.sh < hook.json      hook mode: reads {"cwd", "tool_input": {"file_path"}} on stdin
#
# Wire it as a pre-edit hook in any harness that has one (optional; smelt works without it):
#   Claude Code (.claude/settings.json):
#     "hooks": { "PreToolUse": [ { "matcher": "Edit|Write|MultiEdit",
#       "hooks": [ { "type": "command", "command": "<skill-dir>/scripts/guard-tests.sh" } ] } ] }
#   Other harnesses: call `guard-tests.sh "<file being edited>"` from their pre-edit hook/plugin
#   and refuse the edit on exit 2.
# Add `.smelt/` to .gitignore.
if [ $# -ge 1 ]; then
  path="$1"; root="$PWD"
else
  input="$(cat)"
  root="$(jq -r '.cwd // empty' <<<"$input")"; root="${root:-$PWD}"
  path="$(jq -r '.tool_input.file_path // empty' <<<"$input")"
fi
top="$(git -C "$root" rev-parse --show-toplevel 2>/dev/null || echo "$root")"
[ -f "$top/.smelt/green" ] || exit 0
if [[ "$path" =~ (^|/)(tests?|__tests__|spec|e2e)/ || "$path" =~ \.(test|spec|adversary|property)\.[a-z]+$ \
   || "$path" =~ (^|/)test_[^/]*\.py$ || "$path" =~ _test\.(go|py)$ || "$path" =~ __snapshots__/ ]]; then
  echo "smelt: green phase — tests are read-only. If this test contradicts the spec, stop and say so; remove .smelt/green to start the next red step." >&2
  exit 2
fi
exit 0
