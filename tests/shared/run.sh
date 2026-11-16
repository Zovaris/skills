#!/usr/bin/env bash
# Offline tests for shared/ scripts. Builds throwaway repos; needs git, node, jq.
set -uo pipefail
S="$(cd "$(dirname "$0")/../../shared" && pwd -P)"
P="$(cd "$(dirname "$0")/../../skills/playbook/scripts" && pwd -P)"
pass=0; fail=0
t() { if eval "$2" >/dev/null 2>&1; then pass=$((pass+1)); else fail=$((fail+1)); echo "FAIL: $1"; fi; }
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
export AGENTS_CONFIG="$T/config.json" FOREMAN_HARNESS=codex

git init -q --bare "$T/remote.git"; git clone -q "$T/remote.git" "$T/repo" 2>/dev/null; cd "$T/repo"
git config user.email t@t; git config user.name t
git commit -q --allow-empty -m "feat(core): init"; git commit -q --allow-empty -m "fix(api): handle nulls"
git push -q origin HEAD:main 2>/dev/null; git remote set-head origin main >/dev/null 2>&1

# commit.sh
t "style is conventional" '[ "$($S/commit.sh style | head -1)" = "style: conventional" ]'
t "rejects trailing period" '! $S/commit.sh check "feat: add x."'
t "rejects non-conventional" '! $S/commit.sh check "Added stuff"'
t "rejects > 72 chars" '! $S/commit.sh check "feat: $(printf "a%.0s" {1..80})"'
t "accepts good message" '$S/commit.sh check "feat(api): add pagination"'
echo a > a.txt; echo b > b.txt
t "requires paths" '! $S/commit.sh "feat(api): add a"'
t "commits only given paths" '$S/commit.sh "feat(api): add a" a.txt && [ "$(git status --short)" = "?? b.txt" ]'

# pr.sh
t "no template → exit 1" '! $S/pr.sh template'
mkdir -p .github; printf '## Summary\n\n## Testing\n' > .github/pull_request_template.md
t "template found once" '[ "$($S/pr.sh template | wc -l | tr -d " ")" = 1 ]'

# cleanup.sh
git worktree add -q -b t1 "$T/wt1" main; (cd "$T/wt1" && git commit -q --allow-empty -m "feat(x): wip")
t "keeps unpushed branch" '! $S/cleanup.sh . t1 && git show-ref -q --verify refs/heads/t1'
git push -q origin t1 2>/dev/null
t "cleans pushed branch" '$S/cleanup.sh . t1 && ! git show-ref -q --verify refs/heads/t1'
git worktree add -q -b t2 "$T/wt2" main; echo dirty > "$T/wt2/x"
t "keeps dirty worktree" '! $S/cleanup.sh . t2 && [ -d "$T/wt2" ]'

# tasks.js
mkdir -p docs/specs/pay
printf '# 01 · A\nStatus: todo\nBlocked by: none\n' > docs/specs/pay/01-a.md
printf '# 02 · B\nStatus: todo\nBlocked by: 01\n' > docs/specs/pay/02-b.md
t "next is 01" 'node $S/tasks.js next | grep -q 01-a.md'
t "02 blocked" '[ "$(node $S/tasks.js ready | wc -l | tr -d " ")" = 1 ]'
node "$S/tasks.js" set docs/specs/pay/01-a.md status=done pr=https://x/1 >/dev/null
t "02 ready after 01 done" 'node $S/tasks.js next | grep -q 02-b.md'
t "rejects bad status" '! node $S/tasks.js set docs/specs/pay/02-b.md status=bogus'

mkdir -p .docs/specs/priv elsewhere/x
printf '# 01 · P\nStatus: todo\nBlocked by: none\n' > .docs/specs/priv/01-p.md
printf '# 01 · E\nStatus: todo\nBlocked by: none\n' > elsewhere/x/01-e.md
t "where finds .docs/specs" 'node $S/tasks.js where | grep -q "/.docs/specs/priv$"'
t "where honours FORGE_TASKS_DIRS" 'FORGE_TASKS_DIRS=elsewhere node $S/tasks.js where | grep -q "/elsewhere/x$"'

# config.sh + harness.sh
t "harness override" '[ "$($S/harness.sh)" = "codex any" ]'
t "model unset → exit 3" '$S/config.sh model cheap; [ $? -eq 3 ]'
$S/config.sh set-model cheap mini >/dev/null
t "model saved per harness" '[ "$($S/config.sh model cheap)" = mini ] && jq -e ".models.codex.cheap" "$AGENTS_CONFIG"'

(cd "$T/repo" && $S/config.sh set --repo tasks.commit false >/dev/null)
t "repo setting overrides, false kept as false" '[ "$(cd "$T/repo" && $S/config.sh get tasks.commit)" = false ]'
t "default applies when unset" '[ "$(cd "$T/repo" && $S/config.sh get foreman.merge)" = auto ]'
t "no default → exit 3" '(cd "$T/repo" && $S/config.sh get tasks.ignore); [ $? -eq 3 ]'
t "task-dir asks for tasks.ignore" 'o="$(cd "$T/repo" && $S/task-dir.sh pay)"; [ $? -eq 3 ] && grep -q "^ask tasks.ignore" <<<"$o"'
(cd "$T/repo" && $S/config.sh set --repo tasks.ignore exclude >/dev/null && $S/task-dir.sh pay >/dev/null && $S/task-dir.sh pay >/dev/null)
t "exclude adds .docs/ once" '[ "$(grep -c "^.docs/$" "$(cd "$T/repo" && git rev-parse --git-path info/exclude)")" = 1 ] && [ -d "$T/repo/.docs/specs/pay" ]'

# playbook setup.sh block
printf '# Rules\n' > "$T/AGENTS.md"
t "block missing" '! $P/setup.sh block status "$T/AGENTS.md"'
$P/setup.sh block add "$T/AGENTS.md" >/dev/null; $P/setup.sh block add "$T/AGENTS.md" >/dev/null
t "block added once" '[ "$(grep -c playbook:start "$T/AGENTS.md")" = 1 ]'
$P/setup.sh block remove "$T/AGENTS.md" >/dev/null
t "block removed, rest kept" '! grep -q playbook "$T/AGENTS.md" && grep -q "# Rules" "$T/AGENTS.md"'

# agent.sh with a fake CLI
echo hi > "$T/p.md"
t "agent.sh pipes prompt to AGENT_CMD" '[ "$(AGENT_CMD=cat $S/agent.sh "$T/p.md")" = hi ]'

echo "shared: $pass passed, $fail failed"; [ $fail -eq 0 ]
