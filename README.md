# skills

Harness-agnostic skills (the open `SKILL.md` format): they work in Claude Code, Codex, OpenCode
or anything that loads skills. Harness-specific bits live in adapters
(`skills/foreman/references/harness.md`); everything else is files, git, bash and node.
`scripts/agent.sh` runs any headless agent CLI (claude, codex, opencode, gemini, or `$AGENT_CMD`).

| Skill | Run as | What |
|---|---|---|
| `silent` | `/silent <task>` | Does the task end to end with no talk; progress only in the to-do list; ends with one line: `done: <PR | commits | uncommitted changes | answer>`. Composes: `/silent /forge build`. |
| `forge` | `/forge [phase \| from <phase>] [fast\|full] <task>` | Workflow: grill → spec/tickets → TDD → test agents → two-axis review → PR → retro, with ADRs, glossary and standards. Start at any phase; `fast` for small changes, `full` for risky ones. |
| `foreman` | `/foreman <tasks>` · `status` · `doctor` | Parallel tasks, one silent worker + worktree per task, each to a PR or report. The foreman sleeps on a zero-token watcher and reads compact status cards. |

Typical flow: `/forge plan` a feature → tickets in `docs/specs/<slug>/` → `/foreman` the
independent tickets (workers run `forge build fast`) → or `/silent /forge build` one ticket here.

## Install

With the [skills CLI](https://github.com/vercel-labs/skills) (Node 22.20+). It picks the agents
to install to (Claude Code, Codex, OpenCode, Cursor…) and uses your existing git/`gh` auth for
this private repo:

```bash
npx skills add Zovaris/skills -g
```

All three, no prompts, only for some agents:

```bash
npx skills add Zovaris/skills -g -y --skill silent --skill forge --skill foreman -a claude-code -a codex
```

Update later with `npx skills update -g`. Drop `-g` to install into the current project only.

For development, link this checkout instead so edits apply at once:

```bash
for s in silent forge foreman; do ln -sfn "$PWD/skills/$s" ~/.agents/skills/$s; ln -sfn ../../.agents/skills/$s ~/.claude/skills/$s; done
```

Then `/foreman doctor`. Foreman state lives in `~/.agents/foreman` (`$FOREMAN_HOME`).

## Hooks (all optional)

Nothing requires a hook; they only remove friction where a harness supports them.

| Hook | Harness | Does |
|---|---|---|
| `start_session` auto-approve (`PermissionRequest`) | Claude Code desktop only | Skips the "Allow" click for each foreman worker. Other harnesses spawn workers with `agent.sh` and don't need it. |
| `skills/forge/scripts/guard-tests.sh` | any with a pre-edit hook | Blocks test-file edits while `.forge/green` exists. Reads Claude Code hook JSON on stdin, or takes the file path as an argument for other harnesses. |

## Test agents (skills/forge/agents)

adversary (spec-blind break-it tests) · regression (fails before the fix, passes after) ·
property (fast-check / Hypothesis invariants) · mutation (Stryker / mutmut on changed files) ·
e2e (Playwright flows) · spec-check and standards (read-only reviewers, never merged).

References studied: kunchenguid/firstmate, deepseek-ai/dsh-superagent-prototype,
mattpocock/skills.
