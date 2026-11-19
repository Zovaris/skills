# Settings

Two JSON files, the repo's first: `<repo>/.smithy/config.json` (this repo only) and
`~/.smithy/config.json` (your defaults). You never edit them by hand:

- **use-smithy setup** asks everything up front, or each skill asks a setting the first time it
  needs it and saves your answer;
- `smithy config list` (in any skill's `scripts/`) shows each setting, its value and where it came
  from; `smithy config set [--repo] <key> <value>` changes one.

| Setting | Default | What it does |
|---|---|---|
| `models.<harness>.cheap` / `.mid` / `.strong` | suggested or ask | Stored per harness (`smithy config set-model <tier> <name>`); on Claude the agent suggests haiku, sonnet, opus. The router (`smithy route`) picks a tier per task: cheap for small, mechanical or read-only work, mid for most features, strong for risky, hard or large work and the last fix round. |
| `agent.effort` | `medium` | Reasoning effort for every agent smithy starts (`smithy agent`, `smithy consult`, warden workers): `low` or `medium`. It is also the cap: `high`, `xhigh` or `max` run at `medium`. Passed as `--effort` (Claude Code) or `-c model_reasoning_effort` (Codex) and as `$AGENT_EFFORT`; CLIs without an effort flag keep their own default. Speed (`fast`/`normal`/`full`) adds agents, never effort. |
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
| `skills/smelt/scripts/smithy guard-tests` | any with a pre-edit hook | Blocks test-file edits during TDD's green phase. |
