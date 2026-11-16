# skills

Agent skills for planned, test-first, parallel software work. They use the open `SKILL.md`
format and work in any harness that loads skills (Claude Code, Codex, OpenCode, Cursor, Gemini…):
everything is files, git, bash and node, and harness-specific bits live in small adapters.

## Start with playbook

**Install `playbook` with everything else.** It is the one skill your agent loads on its own at
the start of any coding work, and it tells the agent which of the other skills are installed,
when to use each one and the rules they share. Without it, the agent only knows the other
skills by their one-line descriptions, and the user-invoked ones never come up unless you type
them. For the strongest effect, let playbook add a short pointer to your agent instructions
file (`AGENTS.md` / `CLAUDE.md`): ask your agent to "run playbook setup".

## Skills

| Skill | Started by | What it does |
|---|---|---|
| `playbook` | the agent | Routes work to the installed skills and holds the shared rules. **Install it.** |
| `forge` | you (`/forge`, `$forge`, `@forge`… per harness): `/forge [brainstorm\|plan\|build [next\|all]\|test\|review\|debug\|… \| from <phase>] [fast\|full] <task>` | One task, step by step: brainstorm → spec → task list → TDD → test agents (adversarial, regression, property, mutation, E2E, security) → review → PR → retro. Start at any phase; `fast` for small changes, `full` for risky ones. Through playbook, the agent can follow it too. |
| `foreman` | you: `/foreman <tasks \| task dir \| board ids \| idea>` · `status` · `cleanup` · `doctor` | Many tasks at once: one silent worker and git worktree per task, each to its own PR or report, supervised from small status cards and a zero-token watcher. |
| `docs` | the agent or you: `/docs init\|adr\|module\|map\|sync\|comments\|search` | ADRs, glossary, module READMEs, a codebase map, doc drift checks, and the comment policy: API doc comments only, the "why" lives in docs. |
| `scout` | the agent or you | Read-only investigation with sources ("can we…", "why does…", "compare…"), on your cheap model. |
| `tend` | you: `/tend <pr…> \| batch <batch>`, or foreman | Keeps open PRs mergeable: fixes CI, rebases after sibling merges, handles review comments. |
| `silent` | you: `/silent <task>` | Does the task with no talk; ends with a short `done: <where it landed>` line. |
| `direct` | the agent | Short, direct replies with no filler or AI tells. Off with "normal mode". |

## Harnesses

Every skill is plain files plus bash, node and git; nothing depends on one vendor. What changes
per harness is how you start a skill, how foreman starts workers and whether a waiting session
can be woken up:

| Harness | Skills folder (global) | Start a skill | Foreman workers | Wake on background exit |
|---|---|---|---|---|
| Claude Code desktop | `~/.claude/skills` | `/forge` | app sessions (`start_session`) | yes |
| Claude Code CLI | `~/.claude/skills` | `/forge` | `claude --bg` | yes |
| Codex CLI | `~/.agents/skills` | `$forge` | `agent.sh` → `codex exec` | no: foreground watcher |
| OpenCode | `~/.config/opencode/skills`, `~/.agents/skills` | `@forge` | `agent.sh` → `opencode run --standalone` | yes |
| Pi | `~/.pi/agent/skills`, `~/.agents/skills` | `/skill:forge` | `agent.sh` → `pi -p` | no: foreground watcher |
| DeepSeek Harness | `~/.dsh/skills`, `~/.agents/skills` | `/forge` | `agent.sh` → `dsh headless` | yes |
| Gemini CLI | `~/.gemini/skills`, `~/.agents/skills` | ask: "use forge" | `agent.sh` → `gemini -p` | with `backgroundCompletionBehavior: inject` |
| Cursor CLI | `~/.cursor/skills`, `~/.agents/skills` | `/forge` | `agent.sh` → `agent -p` | no: foreground watcher |

`shared/agent.sh` runs workers headless with each CLI's flags for writing files, running commands
and opening PRs without prompts (`AGENT_CLI` picks one, `AGENT_ARGS` adds flags, `AGENT_CMD`
plugs in anything else). User-invoked skills (forge, foreman, silent, tend) stay out of the model's
reach where the harness supports it (`disable-model-invocation`, and `agents/openai.yaml` for
Codex); Gemini has no such switch.

## How they fit together

![forge and foreman share one task list](docs/flow.svg)

- One **task list** (`NN-<slug>.md` files with `Status`, `Blocked by`, `PR`) on your board, in the
  repo (`docs/specs/<slug>/`) or locally (`~/.agents/plans/<repo>/<slug>/`). forge writes and
  builds it one task at a time (`build next`, `build all`); foreman runs the ready tasks in
  parallel and tend keeps their PRs green.
- Start with forge and hand the rest to foreman, or start with foreman and let it ask for a plan.
- Commits are atomic in your repo's style, PRs follow your template, and finished worktrees and
  local branches are removed every time.

## Install

With the [skills CLI](https://github.com/vercel-labs/skills) (Node 22.20+):

```bash
npx skills add Zovaris/skills -g
```

Pick the skills and agents to install to; include `playbook`. Without prompts:

```bash
npx skills add Zovaris/skills -g -y --skill '*' -a claude-code -a codex
```

Pin a release with `Zovaris/skills@v0.6.0`; update with `npx skills update -g`; drop `-g` to
install into the current project only.

Then run playbook setup (see [Start with playbook](#start-with-playbook)).

## Settings

Two JSON files, the repo's first: `<repo>/.agents/config.json` (this repo only) and
`~/.agents/config.json` (your defaults). You never edit them by hand:

- **playbook setup** asks everything up front, or each skill asks a setting the first time it
  needs it and saves your answer;
- `config.sh list` (in any skill's `scripts/`) shows each setting, its value and where it came
  from; `config.sh set [--repo] <key> <value>` changes one.

| Setting | Default | What it does |
|---|---|---|
| `models.<harness>.cheap` / `.mid` / `.strong` | suggested or ask | Stored per harness (`config.sh set-model <tier> <name>`); on Claude the agent suggests haiku, sonnet, opus. The router (`route.js`) picks a tier per task: cheap for small, mechanical or read-only work, mid for most features, strong for risky, hard or large work and the last fix round. |
| `foreman.worker_model` | `route` | `route`: a tier per task; `session`: the parent's model; or one model name for every worker. |
| `tasks.commit` | ask | Commit specs and tasks (`docs/specs/`) or keep them out of git (`.docs/specs/`). |
| `tasks.ignore` | ask | When not committed: a committed `.gitignore` line, or `.git/info/exclude` (this machine only). |
| `tasks.location` | `repo` | `repo`, `local` (`~/.agents/plans`) or `board`. |
| `foreman.merge` / `foreman.cleanup` | `auto` / `auto` | Merge green PRs; end finished workers and remove their worktrees and branches without asking. |
| `foreman.max` / `foreman.mode` | `3` / `forge fast` | Parallel workers; how workers build: `forge fast`, `forge normal`, `forge full` or `plain`. |
| `tend.watch` / `tend.label` | `prs` / `agent` | What `/tend watch` follows; the issue label it may queue. |

## Hooks (all optional)

| Hook | Harness | Does |
|---|---|---|
| `start_session` auto-approve (`PermissionRequest`) | Claude Code desktop | Skips the "Allow" click per foreman worker. `/foreman doctor` checks it only there. |
| `skills/forge/scripts/guard-tests.sh` | any with a pre-edit hook | Blocks test-file edits during TDD's green phase. |

## Development

- Scripts used by several skills live in `shared/`; edit them there and run
  `scripts/sync-shared.sh`, which copies them into each skill (each skill installs on its own).
- `tests/run.sh` runs every offline test (shared scripts, skill lint, and the docs, foreman,
  scout and tend scripts); CI runs it.
- `scripts/drill.sh` pressure-tests skills against a real agent CLI (`tests/drill/*.md`); it
  costs tokens, so run it by hand per harness.

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
