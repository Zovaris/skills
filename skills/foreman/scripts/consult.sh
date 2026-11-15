#!/usr/bin/env bash
# foreman: asks the strongest available model once, with no tools: ~1k tokens.
#   consult.sh "<question>" "<options, verbatim and in neutral order>"
# Model CLI: $CONSULT_CMD (prompt on stdin) if set; else claude with no tools/MCP/settings;
# else any agent CLI through agent.sh --readonly. The answer may start with NEED-INFO: or ESCALATE:.
set -euo pipefail
[ $# -eq 2 ] || { echo 'usage: consult.sh "<question>" "<options>"' >&2; exit 2; }
DIR="$(cd "$(dirname "$0")" && pwd -P)"
tmp="$(mktemp -d)"; cd "$tmp"
cat > prompt.md <<EOF
You are a senior engineer choosing between options. Answer briefly.
$1. Options: $2. Pick one, 5 lines max. If none fits or you need more information, answer NEED-INFO: <what>. If a product owner should decide (customer-visible behavior, money, data, security, public API, prod, irreversible), answer ESCALATE: <why>.
EOF
if [ -n "${CONSULT_CMD:-}" ]; then bash -c "$CONSULT_CMD" < prompt.md
elif command -v claude >/dev/null 2>&1; then
  claude -p --model "${CONSULT_MODEL:-opus}" --tools "" --strict-mcp-config --disable-slash-commands \
    --setting-sources "" --no-session-persistence < prompt.md
else AGENT_MODEL="${CONSULT_MODEL:-}" "$DIR/agent.sh" --readonly prompt.md; fi
rm -rf "$tmp"
