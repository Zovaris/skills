#!/usr/bin/env bash
# Harness-agnostic agent runner: runs one headless coding agent on a prompt file.
#   agent.sh [--bg] [--cwd <dir>] [--log <file>] [--model <m>] [--readonly] <prompt-file>
# Agent CLI, first match wins:
#   $AGENT_CMD   any shell command; it gets the prompt on stdin and in $AGENT_PROMPT_FILE,
#                the model in $AGENT_MODEL, and $AGENT_READONLY=1 for read-only runs
#   claude       claude -p                     (Claude Code)
#   codex        codex exec                    (OpenAI Codex CLI)
#   opencode     opencode run                  (OpenCode)
#   gemini       gemini -p                     (Gemini CLI)
# --bg prints the pid and returns at once (output goes to --log); otherwise prints the agent's
# final output and exits with its code.
set -euo pipefail
bg=0; cwd="$PWD"; log=""; model="${AGENT_MODEL:-}"; ro=0
while [ $# -gt 1 ]; do case "$1" in
  --bg) bg=1; shift ;; --cwd) cwd="$2"; shift 2 ;; --log) log="$2"; shift 2 ;;
  --model) model="$2"; shift 2 ;; --readonly) ro=1; shift ;; *) break ;; esac; done
[ $# -eq 1 ] && [ -f "$1" ] || { echo 'usage: agent.sh [--bg] [--cwd dir] [--log file] [--model m] [--readonly] <prompt-file>' >&2; exit 2; }
pf="$(cd "$(dirname "$1")" && pwd -P)/$(basename "$1")"
have() { command -v "$1" >/dev/null 2>&1; }

if [ -n "${AGENT_CMD:-}" ]; then cmd="{ $AGENT_CMD
} < \"\$AGENT_PROMPT_FILE\""
elif have claude; then
  perm="${AGENT_PERMISSION_MODE:-acceptEdits}"; [ $ro -eq 1 ] && perm=plan
  cmd="claude -p --permission-mode $perm ${model:+--model $model} < \"\$AGENT_PROMPT_FILE\""
elif have codex; then
  sb="workspace-write"; [ $ro -eq 1 ] && sb="read-only"
  cmd="codex exec --sandbox $sb ${model:+-m $model} - < \"\$AGENT_PROMPT_FILE\""
elif have opencode; then cmd="opencode run ${model:+-m $model} \"\$(cat \"\$AGENT_PROMPT_FILE\")\""
elif have gemini; then cmd="gemini ${model:+-m $model} -p \"\$(cat \"\$AGENT_PROMPT_FILE\")\""
else echo "no agent CLI found: set AGENT_CMD or install claude, codex, opencode or gemini" >&2; exit 1; fi

export AGENT_PROMPT_FILE="$pf" AGENT_MODEL="$model" AGENT_READONLY="$ro"
cd "$cwd"
if [ $bg -eq 1 ]; then
  log="${log:-$(mktemp -t agent).log}"
  nohup bash -c "$cmd" >"$log" 2>&1 </dev/null &
  echo "$! $log"
else
  if [ -n "$log" ]; then bash -c "$cmd" 2>&1 | tee "$log"; else bash -c "$cmd"; fi
fi
