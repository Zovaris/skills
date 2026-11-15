#!/usr/bin/env bash
# /foreman doctor: checks everything a foreman batch needs. Prints one line per check.
# Exit 0 when nothing failed (warnings allowed), 1 otherwise.
fail=0
Q=0; [ "${1:-}" = "--quiet" ] && Q=1
ok()   { [ $Q -eq 1 ] || printf '  ok    %s\n' "$1"; }
warn() { printf '  warn  %s\n        fix: %s\n' "$1" "$2"; }
bad()  { printf '  FAIL  %s\n        fix: %s\n' "$1" "$2"; fail=1; }
have() { command -v "$1" >/dev/null 2>&1; }

[ $Q -eq 1 ] || echo "foreman doctor"

# Tools the foreman and workers run.
for t in git gh jq node; do
  have "$t" && ok "$t found" || bad "$t missing" "install $t (brew install $t)"
done
# Headless agent CLI for agent.sh / consult.sh (any harness).
cli=""; [ -n "${AGENT_CMD:-}" ] && cli="AGENT_CMD"
[ -z "$cli" ] && for c in claude codex opencode gemini; do have "$c" && { cli="$c"; break; }; done
[ -n "$cli" ] && ok "agent CLI: $cli" || warn "no headless agent CLI on PATH (agent.sh adapter, consult.sh)" "install one (claude, codex, opencode, gemini) or set AGENT_CMD; in-app sessions still work"
have gh && { gh auth status >/dev/null 2>&1 && ok "gh signed in" || bad "gh not signed in" "gh auth login"; }

# Skills the workers use: forge (workflow) and silent (no talk).
SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd -P)"
for s in forge silent; do
  found=""
  for f in ~/.agents/skills/$s/SKILL.md ~/.claude/skills/$s/SKILL.md "$SKILL_DIR/../$s/SKILL.md"; do [ -f "$f" ] && { found="$f"; break; }; done
  [ -n "$found" ] && ok "$s skill: $found" || warn "$s skill not found" "ln -sfn <repo>/$s ~/.agents/skills/$s (and link it into your harness's skills dir)"
done

# Claude Code desktop only: session starts auto-approved (no 'Allow once' card per worker).
S=~/.claude/settings.json
if [ ! -d ~/.claude ]; then :
elif have jq && [ -f "$S" ] && jq -e '.hooks.PermissionRequest[]? | select(.matcher=="mcp__ccd_session__start_session") | .hooks[] | select(.command|test("\"behavior\":\"allow\""))' "$S" >/dev/null 2>&1
then ok "start_session auto-approve hook"
else warn "Claude desktop: no start_session auto-approve hook (one click per worker)" "add a PermissionRequest hook, matcher mcp__ccd_session__start_session, printing {\"hookSpecificOutput\":{\"hookEventName\":\"PermissionRequest\",\"decision\":{\"behavior\":\"allow\"}}}"; fi

# State dir.
d="${FOREMAN_HOME:-$HOME/.agents/foreman}"
mkdir -p "$d" 2>/dev/null && [ -w "$d" ] && ok "writable $d" || bad "cannot write $d" "check permissions on $d"

# Workspace rules the workers follow (AGENTS.md or CLAUDE.md, here or in a parent folder).
C=""; d="${FOREMAN_WORKSPACE:-$PWD}"
while :; do for n in AGENTS.md CLAUDE.md; do [ -f "$d/$n" ] && { C="$d/$n"; break 2; }; done; [ "$d" = / ] && break; d="$(dirname "$d")"; done
[ -n "$C" ] && ok "agent instructions for workers: $C" || warn "no AGENTS.md / CLAUDE.md here or in a parent folder" "optional: workers follow forge and the brief"

[ $fail -eq 0 ] && echo "ready" || echo "not ready"
exit $fail
