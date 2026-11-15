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
| `forge` | you: `/forge [brainstorm\|plan\|build [next\|all]\|test\|review\|debug\|… \| from <phase>] [fast\|full] <task>` | One task, step by step: brainstorm → spec → task list → TDD → test agents (adversarial, regression, property, mutation, E2E, security) → review → PR → retro. Start at any phase; `fast` for small changes, `full` for risky ones. Through playbook, the agent can follow it too. |
| `foreman` | you: `/foreman <tasks \| task dir \| board ids \| idea>` · `status` · `cleanup` · `doctor` | Many tasks at once: one silent worker and git worktree per task, each to its own PR or report, supervised from small status cards and a zero-token watcher. |
| `docs` | the agent or you: `/docs init\|adr\|module\|map\|sync\|comments\|search` | ADRs, glossary, module READMEs, a codebase map, doc drift checks, and the comment policy: API doc comments only, the "why" lives in docs. |
| `scout` | the agent or you | Read-only investigation with sources ("can we…", "why does…", "compare…"), on your cheap model. |
| `tend` | you: `/tend <pr…> \| batch <batch>`, or foreman | Keeps open PRs mergeable: fixes CI, rebases after sibling merges, handles review comments. |
| `silent` | you: `/silent <task>` | Does the task with no talk; ends with one line, `done: <where it landed>`. |
| `direct` | the agent | Short, direct replies with no filler or AI tells. Off with "normal mode". |

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

Pin a release with `Zovaris/skills@v0.4.0`; update with `npx skills update -g`; drop `-g` to
install into the current project only.

Then ask your agent to **run playbook setup**. It shows what is installed, asks once which cheap
and strong models to use in this harness (saved in `~/.agents/config.json`, nothing is
hard-coded), and offers to add the playbook pointer to your agent instructions file.

## Models

Scouts, reviewers and simple workers use your **cheap** model; second opinions and the last fix
round use your **strong** one. You pick both per harness (Haiku, a GPT mini, anything your CLI
accepts); skills read them with `config.sh model cheap|strong`.

## Hooks (all optional)

| Hook | Harness | Does |
|---|---|---|
| `start_session` auto-approve (`PermissionRequest`) | Claude Code desktop | Skips the "Allow" click per foreman worker. `/foreman doctor` checks it only there. |
| `skills/forge/scripts/guard-tests.sh` | any with a pre-edit hook | Blocks test-file edits during TDD's green phase. |

## Development

- Scripts used by several skills live in `shared/`; edit them there and run
  `scripts/sync-shared.sh`, which copies them into each skill (each skill installs on its own).
- `tests/run.sh` runs every offline test (shared scripts, skill lint, per-skill tests); CI runs it.
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
