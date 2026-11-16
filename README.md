# smithy

Agent skills for planned, test-first, parallel software work. They use the open `SKILL.md`
format and work in any harness that loads skills (Claude Code, Codex, OpenCode, Cursor, Gemini…):
everything is files, git, bash and node, and harness-specific bits live in small adapters.
GitHub work goes through the GitHub CLI (`gh`), which `/warden doctor` checks.

## Start with use-smithy

**Install `use-smithy` with everything else.** It is the one skill your agent loads on its own at
the start of any coding work, and it tells the agent which of the other skills are installed,
when to use each one and the rules they share. Without it, the agent only knows the other
skills by their one-line descriptions, and the user-invoked ones never come up unless you type
them. For the strongest effect, let use-smithy add a short pointer to your agent instructions
file (`AGENTS.md` / `CLAUDE.md`): ask your agent to "run use-smithy setup".

## Skills

| Skill | Started by | What it does |
|---|---|---|
| `use-smithy` | the agent | Routes work to the installed skills and holds the shared rules. **Install it.** |
| `smelt` | you (`/smelt`, `$smelt`, `@smelt`… per harness): `/smelt [brainstorm\|plan\|build [next\|all]\|test\|review\|debug\|… \| from <phase>] [fast\|full] <task>` | One task, step by step: brainstorm → spec → task list → TDD → test agents (adversarial, regression, property, mutation, E2E, security) → review → PR → retro. Start at any phase; `fast` for small changes, `full` for risky ones. Through use-smithy, the agent can follow it too. |
| `warden` | you: `/warden <tasks \| task dir \| board ids \| idea>` · `status [all]` · `cleanup` · `doctor` | Many tasks at once: one silent worker and git worktree per task, each to its own PR or report, supervised from small status cards and a zero-token watcher. |
| `ledger` | the agent or you: `/ledger init\|adr\|module\|map\|sync\|comments\|search` | ADRs, glossary, module READMEs, a codebase map, doc drift checks, and the comment policy: API doc comments only, the "why" lives in docs. |
| `scout` | the agent or you | Read-only investigation with sources ("can we…", "why does…", "compare…"), on your cheap model. |
| `tend` | you: `/tend <pr…> \| batch <batch> \| watch [prs\|issues\|all]`, or warden | Keeps open PRs mergeable: fixes CI, rebases after sibling merges, handles review comments. |
| `hush` | you: `/hush <task>` | Does the task with no talk; ends with a short `done: <where it landed>` line. |
| `simple` | the agent | Short, direct replies with no filler or AI tells. Off with "normal mode". |

## Harnesses

Every skill is plain files plus bash, node and git; nothing depends on one vendor. What changes
per harness is how you start a skill, how warden starts workers and whether a waiting session
can be woken up:

| Harness | Skills folder (global) | Start a skill | Warden workers | Wake on background exit |
|---|---|---|---|---|
| Claude Code desktop | `~/.claude/skills` | `/smelt` | app sessions (`start_session`) | yes |
| Claude Code CLI | `~/.claude/skills` | `/smelt` | `claude --bg` | yes |
| Codex CLI | `~/.agents/skills` | `$smelt` | `agent.sh` → `codex exec` | no: foreground watcher |
| OpenCode | `~/.config/opencode/skills`, `~/.agents/skills` | `@smelt` | `agent.sh` → `opencode run --standalone` | yes |
| Pi | `~/.pi/agent/skills`, `~/.agents/skills` | `/skill:smelt` | `agent.sh` → `pi -p` | no: foreground watcher |
| DeepSeek Harness | `~/.dsh/skills`, `~/.agents/skills` | `/smelt` | `agent.sh` → `dsh headless` | yes |
| Gemini CLI | `~/.gemini/skills`, `~/.agents/skills` | ask: "use smelt" | `agent.sh` → `gemini -p` | with `backgroundCompletionBehavior: inject` |
| Cursor CLI | `~/.cursor/skills`, `~/.agents/skills` | `/smelt` | `agent.sh` → `agent -p` | no: foreground watcher |

`shared/agent.sh` runs workers headless with each CLI's flags for writing files, running commands
and opening PRs without prompts (`AGENT_CLI` picks one, `AGENT_ARGS` adds flags, `AGENT_CMD`
plugs in anything else). User-invoked skills (smelt, warden, hush, tend) stay out of the model's
reach where the harness supports it (`disable-model-invocation`, and `agents/openai.yaml` for
Codex); Gemini has no such switch.

## How they fit together

![smelt and warden share one task list](docs/flow.svg)

- One **task list** (`NN-<slug>.md` files with `Status`, `Blocked by`, `PR`) on your board, in the
  repo (`docs/specs/<slug>/`) or locally (`~/.smithy/plans/<repo>/<slug>/`). smelt writes and
  builds it one task at a time (`build next`, `build all`); warden runs the ready tasks in
  parallel and tend keeps their PRs green.
- Start with smelt and hand the rest to warden, or start with warden and let it ask for a plan.
- No tracker? `smithy tasks board --all` (or `/warden status all`) lists every task list and batch on
  your machine.
- Branches are named one way everywhere: `<type>/<key>-<slug>` (`feat/PROJ-123-add-login`,
  `fix/42-null-crash`), with the ticket, issue or task number as the key; worktrees sit next to
  the repo in `../worktrees/`.
- Commits are atomic in your repo's style, PRs follow your template, and finished worktrees and
  local branches are removed every time.

## Waiting without tokens

Agents never sleep and re-check. They run `smithy wait` in the background; it polls GitHub with
`gh` and exits with one line when something happens, which wakes the agent:

```bash
smithy wait pr:42                 # checks finished (green/red + failed names), merged, closed, conflict, review, comment
smithy wait run:123 branch:main   # a workflow run, or every run on the branch's latest commit
smithy wait prs issues:agent      # new or updated PRs (yours or a batch's) and labeled issues
smithy wait batch:20261115-1030   # a warden card that needs the warden
```

Mix targets in one call; pick events with `--events` or the `watch.events` setting.

## Install

With the [skills CLI](https://github.com/vercel-labs/skills) (Node 22.20+):

```bash
npx skills add Zovaris/skills -g
```

Pick the skills and agents to install to; include `use-smithy`. Without prompts:

```bash
npx skills add Zovaris/skills -g -y --skill '*' -a claude-code -a codex
```

Pin a release with `Zovaris/skills@v0.7.0`; update with `npx skills update -g`; drop `-g` to
install into the current project only.

Then run use-smithy setup (see [Start with use-smithy](#start-with-use-smithy)).

### The smithy binary

The scripts behind the skills are one Go binary, `smithy` (settings, branch names, task lists,
warden cards, waiting on GitHub). You don't install it yourself: each skill ships a small
launcher (`scripts/smithy`, and `smithy.cmd` for Windows) that, the first time it runs,
downloads the binary for your platform from the matching GitHub release (~1.5 MB gzipped),
checks it against the release's `checksums.txt` and its build attestation, and keeps it in
`~/.smithy/bin/<version>/`. `~/.smithy/bin/smithy` points at the current one; add `~/.smithy/bin`
to your `PATH` to run `smithy status` (every task list and batch) yourself. `SMITHY_BIN` points
the launcher at your own build.

## Settings

Two JSON files, the repo's first: `<repo>/.smithy/config.json` (this repo only) and
`~/.smithy/config.json` (your defaults). You never edit them by hand:

- **use-smithy setup** asks everything up front, or each skill asks a setting the first time it
  needs it and saves your answer;
- `smithy config list` (in any skill's `scripts/`) shows each setting, its value and where it came
  from; `smithy config set [--repo] <key> <value>` changes one.

| Setting | Default | What it does |
|---|---|---|
| `models.<harness>.cheap` / `.mid` / `.strong` | suggested or ask | Stored per harness (`smithy config set-model <tier> <name>`); on Claude the agent suggests haiku, sonnet, opus. The router (`route.js`) picks a tier per task: cheap for small, mechanical or read-only work, mid for most features, strong for risky, hard or large work and the last fix round. |
| `warden.worker_model` | `route` | `route`: a tier per task; `session`: the parent's model; or one model name for every worker. |
| `tasks.commit` | ask | Commit specs and tasks (`docs/specs/`) or keep them out of git (`.docs/specs/`). |
| `tasks.ignore` | ask | When not committed: a committed `.gitignore` line, or `.git/info/exclude` (this machine only). |
| `tasks.location` | `repo` | `repo`, `local` (`~/.smithy/plans`) or `board`. |
| `warden.merge` / `warden.cleanup` | `auto` / `auto` | Merge green PRs; end finished workers and remove their worktrees and branches without asking. |
| `warden.max` / `warden.mode` | `3` / `smelt fast` | Parallel workers; how workers build: `smelt fast`, `smelt normal`, `smelt full` or `plain`. |
| `tend.watch` / `tend.label` | `prs` / `agent` | What `/tend watch` follows; the issue label it may queue. |
| `git.branch` | `{type}/{key}-{slug}` | Branch names (`smithy names`); e.g. `agent/{key}-{slug}`. |
| `git.worktree` | `{parent}/worktrees/{repo}-{branch}` | Where worktrees go. |
| `watch.events` / `watch.every` / `watch.max` | all / `30` / `50` | What wakes a waiting agent, seconds between polls, minutes before a heartbeat. |

Coming from 0.7 (`~/.agents/`): the first run moves your settings, plans and batches to
`~/.smithy/` (`smithy config migrate` does it by hand).

## Hooks (all optional)

| Hook | Harness | Does |
|---|---|---|
| `start_session` auto-approve (`PermissionRequest`) | Claude Code desktop | Skips the "Allow" click per warden worker. `/warden doctor` checks it only there. |
| `skills/smelt/scripts/guard-tests.sh` | any with a pre-edit hook | Blocks test-file edits during TDD's green phase. |

## Development

- The binary's source is in `cmd/smithy` and `internal/` (Go, standard library only). Inside a
  checkout the launcher builds it from source when a `.go` file changed, so symlinked skills
  always run your working copy.
- Pull requests run `check` (gofmt, vet, `go test`, every offline test through the binary, a
  build per release target). A `v*` tag runs `release`: it checks the tag matches
  `shared/VERSION`, builds darwin, linux (arm64, amd64) and windows binaries, gzips them,
  writes `checksums.txt`, attests the build and publishes the GitHub release with the
  CHANGELOG section as notes.
- Scripts used by several skills live in `shared/`; edit them there and run
  `scripts/sync-shared.sh`, which copies them into each skill (each skill installs on its own).
- `tests/run.sh` runs every offline test (shared scripts, skill lint, and the ledger, warden,
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
