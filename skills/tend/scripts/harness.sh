#!/usr/bin/env bash
# foreman: prints the harness this shell runs in and the adapter to use (references/harness.md).
#   harness.sh            -> "<harness> <adapter>", e.g. "claude-desktop desktop"
# Harness: claude-desktop | claude-cli | codex | opencode | gemini | cursor | unknown
# Adapter: desktop | cli | any
# $FOREMAN_HARNESS overrides detection (same names). Detection uses only env vars each
# harness sets for its child processes; AI_AGENT is the cross-tool convention, checked last.
h="${FOREMAN_HARNESS:-}"
if [ -z "$h" ]; then
  if [ "${CLAUDE_CODE_ENTRYPOINT:-}" = "claude-desktop" ]; then h=claude-desktop
  elif [ -n "${CLAUDECODE:-}" ] || [ -n "${CLAUDE_CODE_ENTRYPOINT:-}" ]; then h=claude-cli
  elif env | grep -q '^CODEX_'; then h=codex
  elif [ -n "${OPENCODE:-}" ] || env | grep -q '^OPENCODE_'; then h=opencode
  elif [ -n "${GEMINI_CLI:-}" ]; then h=gemini
  elif [ -n "${CURSOR_AGENT:-}" ] || [ -n "${CURSOR_TRACE_ID:-}" ]; then h=cursor
  else
    case "${AI_AGENT:-}" in
      claude*) h=claude-cli ;; codex*) h=codex ;; opencode*) h=opencode ;;
      gemini*) h=gemini ;; cursor*) h=cursor ;; *) h=unknown ;;
    esac
  fi
fi
case "$h" in claude-desktop) a=desktop ;; claude-cli) a=cli ;; *) a=any ;; esac
echo "$h $a"
