#!/usr/bin/env bash
# Harness-agnostic agent runner: runs one headless coding agent on a prompt file.
#   agent.sh [--bg] [--cwd <dir>] [--log <file>] [--model <m>] [--readonly] <prompt-file>
# Agent CLI: $AGENT_CLI picks one by name; else the first installed of the list below.
#   AGENT_CMD   any shell command; gets the prompt on stdin and in $AGENT_PROMPT_FILE, the model
#               in $AGENT_MODEL, and $AGENT_READONLY=1 for read-only runs
#   claude      claude -p --permission-mode ${AGENT_PERMISSION_MODE:-auto}   (plan when read-only)
#   codex       codex exec --sandbox workspace-write, the repo's git dir writable and network on
#               (so workers can commit, push and open PRs); read-only sandbox when read-only
#   opencode    opencode run --standalone --auto (plan agent when read-only); -m provider/model
#   gemini      gemini -p --approval-mode yolo (plan when read-only)
#   cursor      agent -p --force (Cursor CLI)
#   pi          pi -p (--tools read when read-only)
#   dsh         dsh headless --approval-policy never (DeepSeek Harness; model from its profile)
# Extra flags for the chosen CLI: $AGENT_ARGS. Workers get FOREMAN_HARNESS set to the CLI and the
# parent harness's variables removed, so their own scripts detect the right harness.
# --bg prints `<pid> <log>` and returns at once; otherwise prints the agent's output when it ends
# and exits with its code (output goes through a file, so a server the CLI leaves running can't
# keep the caller waiting).
set -euo pipefail
bg=0; cwd="$PWD"; log=""; model="${AGENT_MODEL:-}"; ro=0
while [ $# -gt 1 ]; do case "$1" in
  --bg) bg=1; shift ;; --cwd) cwd="$2"; shift 2 ;; --log) log="$2"; shift 2 ;;
  --model) model="$2"; shift 2 ;; --readonly) ro=1; shift ;; *) break ;; esac; done
[ $# -eq 1 ] && [ -f "$1" ] || { echo 'usage: agent.sh [--bg] [--cwd dir] [--log file] [--model m] [--readonly] <prompt-file>' >&2; exit 2; }
pf="$(cd "$(dirname "$1")" && pwd -P)/$(basename "$1")"
have() { command -v "$1" >/dev/null 2>&1; }
P='"$(cat "$AGENT_PROMPT_FILE")"'
X="${AGENT_ARGS:-}"

cli="${AGENT_CLI:-}"
if [ -z "$cli" ] && [ -z "${AGENT_CMD:-}" ]; then
  for c in claude codex opencode gemini cursor pi dsh; do
    b="$c"; [ "$c" = cursor ] && b=agent
    have "$b" && { cli="$c"; break; }
  done
fi
[ -n "${AGENT_CMD:-}" ] && cli=custom

case "$cli" in
  custom) cmd="{ $AGENT_CMD
} < \"\$AGENT_PROMPT_FILE\"" ;;
  claude)
    perm="${AGENT_PERMISSION_MODE:-auto}"; [ $ro -eq 1 ] && perm=plan
    cmd="claude -p --permission-mode $perm ${model:+--model $model} $X < \"\$AGENT_PROMPT_FILE\"" ;;
  codex)
    if [ $ro -eq 1 ]; then sb="--sandbox read-only"
    else
      gd="$(git -C "$cwd" rev-parse --path-format=absolute --git-common-dir 2>/dev/null || true)"
      sb="--sandbox workspace-write -c sandbox_workspace_write.network_access=true ${gd:+--add-dir $gd}"
    fi
    cmd="codex exec $sb ${model:+-m $model} $X - < \"\$AGENT_PROMPT_FILE\"" ;;
  opencode)
    perm="--auto"; [ $ro -eq 1 ] && perm="--agent plan"
    cmd="opencode run --standalone --archived $perm ${model:+-m $model} $X $P </dev/null" ;;
  gemini)
    perm="--approval-mode yolo"; [ $ro -eq 1 ] && perm="--approval-mode plan"
    cmd="gemini $perm ${model:+-m $model} $X -p $P </dev/null" ;;
  cursor) cmd="agent -p --force ${model:+--model $model} $X $P </dev/null" ;;
  pi)
    t=""; [ $ro -eq 1 ] && t="--tools read"
    cmd="pi -p $t ${model:+--model $model} $X $P </dev/null" ;;
  dsh)
    perm=""; [ $ro -eq 1 ] && perm="--permission-mode read-only"
    cmd="dsh headless --approval-policy never $perm $X - < \"\$AGENT_PROMPT_FILE\"" ;;
  *) echo "no agent CLI found: install claude, codex, opencode, gemini, cursor (agent), pi or dsh, or set AGENT_CMD" >&2; exit 1 ;;
esac

export AGENT_PROMPT_FILE="$pf" AGENT_MODEL="$model" AGENT_READONLY="$ro"
case "$cli" in claude) h=claude-cli ;; custom) h="${FOREMAN_HARNESS:-unknown}" ;; *) h="$cli" ;; esac
cmd="unset CLAUDECODE CLAUDE_CODE_ENTRYPOINT CODEX_THREAD_ID OPENCODE OPENCODE_SESSION_ID GEMINI_CLI PI_CODING_AGENT DSH_SESSION_ID AI_AGENT; export FOREMAN_HARNESS=$h; $cmd"
cd "$cwd"
if [ $bg -eq 1 ]; then
  log="${log:-$(mktemp "${TMPDIR:-/tmp}/agent.XXXXXX")}"
  nohup bash -c "$cmd" >"$log" 2>&1 </dev/null &
  echo "$! $log"
else
  out="${log:-$(mktemp "${TMPDIR:-/tmp}/agent.XXXXXX")}"
  set +e; bash -c "$cmd" >"$out" 2>&1 </dev/null; rc=$?; set -e
  cat "$out"; [ -n "$log" ] || rm -f "$out"
  exit $rc
fi
