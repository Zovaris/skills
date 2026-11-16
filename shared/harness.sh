#!/usr/bin/env bash
# Prints the harness this shell runs in and the adapter to use (warden references/harness.md).
#   harness.sh            -> "<harness> <adapter>", e.g. "claude-desktop desktop"
# Harness: claude-desktop | claude-cli | codex | opencode | gemini | pi | dsh | cursor | unknown
# Adapter: desktop | cli | any
# $WARDEN_HARNESS overrides detection (agent.sh sets it for workers). Detection uses only the
# variables each harness sets for its own child processes, not user settings like CODEX_HOME;
# AI_AGENT (a cross-tool convention) and Cursor's unreliable variables come last.
h="${WARDEN_HARNESS:-}"
if [ -z "$h" ]; then
  if [ "${CLAUDE_CODE_ENTRYPOINT:-}" = "claude-desktop" ]; then h=claude-desktop
  elif [ -n "${CLAUDECODE:-}" ] || [ -n "${CLAUDE_CODE_ENTRYPOINT:-}" ]; then h=claude-cli
  elif [ -n "${CODEX_THREAD_ID:-}${CODEX_CI:-}${CODEX_SANDBOX:-}${CODEX_SANDBOX_NETWORK_DISABLED:-}" ]; then h=codex
  elif [ -n "${OPENCODE:-}${OPENCODE_SESSION_ID:-}" ]; then h=opencode
  elif [ -n "${GEMINI_CLI:-}" ]; then h=gemini
  elif [ -n "${PI_CODING_AGENT:-}${PI_SESSION_ID:-}" ]; then h=pi
  elif [ -n "${DSH_SESSION_ID:-}" ]; then h=dsh
  else
    case "${AI_AGENT:-}" in
      claude*) h=claude-cli ;; codex*) h=codex ;; opencode*) h=opencode ;; gemini*) h=gemini ;;
      pi*) h=pi ;; dsh*|deepseek*) h=dsh ;; cursor*) h=cursor ;;
      *) if [ -n "${CURSOR_AGENT:-}${CURSOR_TRACE_ID:-}" ]; then h=cursor; else h=unknown; fi ;;
    esac
  fi
fi
case "$h" in claude-desktop) a=desktop ;; claude-cli) a=cli ;; *) a=any ;; esac
echo "$h $a"
