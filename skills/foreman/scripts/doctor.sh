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
# Harness: decides which adapter applies and which checks are relevant (no false alarms).
read -r HARNESS ADAPTER <<<"$("$(dirname "$0")/harness.sh")"
ok "harness: $HARNESS (adapter: $ADAPTER; override with FOREMAN_HARNESS)"

# Headless agent CLI: required to spawn workers with the 'any' adapter; else only consult.sh uses it.
cli=""; [ -n "${AGENT_CMD:-}" ] && cli="AGENT_CMD"
[ -z "$cli" ] && for c in claude codex opencode gemini; do have "$c" && { cli="$c"; break; }; done
if [ -n "$cli" ]; then ok "agent CLI: $cli"
elif [ "$ADAPTER" = any ]; then bad "no headless agent CLI on PATH (needed to spawn workers here)" "install one (claude, codex, opencode, gemini) or set AGENT_CMD"
else warn "no headless agent CLI on PATH (only consult.sh needs it here)" "optional: install one or set AGENT_CMD"; fi
have gh && { gh auth status >/dev/null 2>&1 && ok "gh signed in" || bad "gh not signed in" "gh auth login"; }

# Skills the workers use: forge (workflow) and silent (no talk).
SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd -P)"
for s in forge silent; do
  found=""
  for f in "$SKILL_DIR/../$s/SKILL.md" ~/.agents/skills/$s/SKILL.md ~/.claude/skills/$s/SKILL.md ~/.codex/skills/$s/SKILL.md ~/.config/opencode/skills/$s/SKILL.md; do [ -f "$f" ] && { found="$f"; break; }; done
  [ -n "$found" ] && ok "$s skill: $found" || warn "$s skill not found" "npx skills add Zovaris/skills -g --skill $s"
done

# Claude Code desktop only: start_session auto-approved (no 'Allow' card per worker).
# Looked for in user, project and local settings; the hook may print the JSON inline or via a script.
if [ "$HARNESS" = claude-desktop ]; then
  hook=""
  for S in ~/.claude/settings.json .claude/settings.json .claude/settings.local.json; do
    [ -f "$S" ] || continue
    while IFS= read -r cmd; do
      [ -z "$cmd" ] && continue
      f="${cmd%% *}"; f="${f/#\~/$HOME}"
      if grep -q '"behavior" *: *"allow"' <<<"$cmd" || { [ -f "$f" ] && grep -q '"behavior" *: *"allow"' "$f"; }; then hook="$S"; break 2; fi
    done < <(jq -r '.hooks.PermissionRequest[]? | select(.matcher != null) | select(.matcher as $m | "mcp__ccd_session__start_session" | test($m)) | .hooks[]?.command // empty' "$S" 2>/dev/null)
  done
  [ -n "$hook" ] && ok "start_session auto-approve hook ($hook)" \
    || warn "no start_session auto-approve hook (one 'Allow' click per worker)" "add a PermissionRequest hook, matcher mcp__ccd_session__start_session, printing {\"hookSpecificOutput\":{\"hookEventName\":\"PermissionRequest\",\"decision\":{\"behavior\":\"allow\"}}}"
fi

# State dir.
d="${FOREMAN_HOME:-$HOME/.agents/foreman}"
mkdir -p "$d" 2>/dev/null && [ -w "$d" ] && ok "writable $d" || bad "cannot write $d" "check permissions on $d"

# Workspace rules the workers follow (AGENTS.md or CLAUDE.md, here or in a parent folder).
C=""; d="${FOREMAN_WORKSPACE:-$PWD}"
while :; do for n in AGENTS.md CLAUDE.md; do [ -f "$d/$n" ] && { C="$d/$n"; break 2; }; done; [ "$d" = / ] && break; d="$(dirname "$d")"; done
[ -n "$C" ] && ok "agent instructions for workers: $C" || warn "no AGENTS.md / CLAUDE.md here or in a parent folder" "optional: workers follow forge and the brief"

[ $fail -eq 0 ] && echo "ready" || echo "not ready"
exit $fail
