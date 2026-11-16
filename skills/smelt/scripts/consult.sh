#!/usr/bin/env bash
# One cheap, tool-less call to the user's strongest model to settle a decision without the user.
#   consult.sh "<question>" "<options, verbatim and in neutral order>" [--context <file>]
# Prints the answer (≤5 lines). It may start with NEED-INFO: <what> (send the question back with
# that) or ESCALATE: <why> (the user decides). Callers log what they decided and why.
# Model: $CONSULT_MODEL, else `config.sh model strong`, else the CLI default.
# CLI: $CONSULT_CMD (prompt on stdin) if set; else the CLI of the harness you're in (harness.sh),
# else the first installed one. Claude runs with no tools, MCP, settings or session (~1k tokens);
# the others run read-only through agent.sh. Nothing here assumes a vendor.
set -euo pipefail
[ $# -ge 2 ] || { echo 'usage: consult.sh "<question>" "<options>" [--context <file>]' >&2; exit 2; }
DIR="$(cd "$(dirname "$0")" && pwd -P)"
q="$1"; o="$2"; ctx=""
[ "${3:-}" = --context ] && [ -f "${4:-}" ] && ctx="$(head -c 6000 "$4")"
model="${CONSULT_MODEL:-$("$DIR/config.sh" model strong 2>/dev/null || true)}"
tmp="$(mktemp -d "${TMPDIR:-/tmp}/consult.XXXXXX")"; trap 'rm -rf "$tmp"' EXIT
cat > "$tmp/prompt.md" <<PROMPT
You are a senior engineer settling one decision so the work can continue. Answer briefly.
Question: $q
Options (neutral order): $o
${ctx:+Context:
$ctx
}Pick one option and give the reason in at most 5 lines. If none fits or you need more
information, answer NEED-INFO: <what>. If a product owner should decide (customer-visible
behaviour, money, data, security, public API, production, irreversible), answer ESCALATE: <why>.
Do not use tools.
PROMPT
if [ -n "${CONSULT_CMD:-}" ]; then bash -c "$CONSULT_CMD" < "$tmp/prompt.md"; exit; fi
h="$("$DIR/harness.sh" | awk '{print $1}')"
case "$h" in claude-*) cli=claude ;; codex|opencode|gemini|pi|dsh|cursor) cli="$h" ;; *) cli="" ;; esac
bin="$cli"; [ "$cli" = cursor ] && bin=agent
[ -n "$cli" ] && ! command -v "$bin" >/dev/null 2>&1 && cli=""
if [ -z "$cli" ]; then for c in claude codex opencode gemini pi dsh; do command -v "$c" >/dev/null 2>&1 && { cli="$c"; break; }; done; fi
cd "$tmp"
if [ "$cli" = claude ]; then
  claude -p ${model:+--model "$model"} --tools "" --strict-mcp-config --disable-slash-commands \
    --setting-sources "" --no-session-persistence < "$tmp/prompt.md"
else
  AGENT_CLI="$cli" "$DIR/agent.sh" --readonly ${model:+--model "$model"} "$tmp/prompt.md"
fi
