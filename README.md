# skills

Harness-agnostic skills (the open `SKILL.md` format): they work in Claude Code, Codex, OpenCode
or anything that loads skills. Harness-specific bits live in adapters
(`skills/foreman/references/harness.md`); everything else is files, git, bash and node.
`scripts/agent.sh` runs any headless agent CLI (claude, codex, opencode, gemini, or `$AGENT_CMD`).

| Skill | Run as | What |
|---|---|---|
| `silent` | `/silent <task>` | Does the task end to end with no talk; progress only in the to-do list; ends with one line: `done: <PR | commits | uncommitted changes | answer>`. Composes: `/silent /forge build`. |
| `forge` | `/forge [brainstorm\|plan\|build [next]\|test\|review\|… \| from <phase>] [fast\|full] <task>` | Workflow: brainstorm (why, approaches) → grill → spec → task list → TDD → test agents → two-axis review → PR → retro, with ADRs, glossary and standards. Start at any phase; `fast` for small changes, `full` for risky ones. |
| `foreman` | `/foreman <tasks \| task dir \| board ids \| idea>` · `status` · `doctor` | One or many tasks in parallel, one silent worker + worktree per task, each to a PR or report. Asks for a plan when given only an idea; workers use forge or plain mode. Sleeps on a zero-token watcher and reads compact status cards. |

Each works alone; installed together they hand off through one **task list** (`NN-<slug>.md`
files with `Status`, `Blocked by` and `PR`, read and updated by `tasks.js`), kept on your board,
in the repo (`docs/specs/<slug>/`) or locally (`~/.agents/plans/<repo>/<slug>/`).

```
/forge plan <idea>        why → approaches → design → spec → task list → "how do we run it?"
  ├─ /forge build next    one task at a time here, until all done
  └─ /foreman <task dir>  the ready tasks in parallel; blocked ones start when their blockers merge
/foreman <idea>           "have a plan? / plan it with forge / I split it / run as one task"
/silent /forge build next one task, no talk, ends with `done: <where it landed>`
```

## How forge and foreman work together

Each skill works alone. Installed together, they hand work to each other through the task list.

![forge and foreman share one task list](docs/flow.svg)

- **Start with forge, finish with anything.** After `/forge plan`, run some tasks here with
  `/forge build next` and hand the rest to `/foreman <task dir>`; both update the same statuses.
- **Start with foreman.** Give it tasks, a task dir, board ids or just an idea; with only an idea
  it asks whether you have a plan, offers `/forge plan`, or splits the idea itself.
- **Blocked tasks wait.** `Blocked by` in each task decides what starts now; foreman launches
  the rest as their blockers merge.

## Install

With the [skills CLI](https://github.com/vercel-labs/skills) (Node 22.20+). It picks the agents
to install to (Claude Code, Codex, OpenCode, Cursor…):

```bash
npx skills add Zovaris/skills -g
```

All three, no prompts, only for some agents:

```bash
npx skills add Zovaris/skills -g -y --skill silent --skill forge --skill foreman -a claude-code -a codex
```

Pin a release with `Zovaris/skills@v0.4.0`. Update later with `npx skills update -g`. Drop `-g`
to install into the current project only.

For development, link this checkout instead so edits apply at once:

```bash
for s in silent forge foreman; do ln -sfn "$PWD/skills/$s" ~/.agents/skills/$s; ln -sfn ../../.agents/skills/$s ~/.claude/skills/$s; done
```

Then `/foreman doctor`. Foreman state lives in `~/.agents/foreman` (`$FOREMAN_HOME`).

## Hooks (all optional)

Nothing requires a hook; they only remove friction where a harness supports them.

| Hook | Harness | Does |
|---|---|---|
| `start_session` auto-approve (`PermissionRequest`) | Claude Code desktop only | Skips the "Allow" click for each foreman worker. Other harnesses spawn workers with `agent.sh` and don't need it; `doctor` only checks it when `harness.sh` detects the desktop app. |
| `skills/forge/scripts/guard-tests.sh` | any with a pre-edit hook | Blocks test-file edits while `.forge/green` exists. Reads Claude Code hook JSON on stdin, or takes the file path as an argument for other harnesses. |

## Versions

One version for the whole repo, tagged `vX.Y.Z` with a GitHub release; see
[CHANGELOG.md](CHANGELOG.md).

## Credits

Ideas borrowed from [firstmate](https://github.com/kunchenguid/firstmate),
[dsh-superagent-prototype](https://github.com/deepseek-ai/dsh-superagent-prototype),
[mattpocock/skills](https://github.com/mattpocock/skills) and
[superpowers](https://github.com/obra/superpowers).

## License

[MIT](LICENSE)
