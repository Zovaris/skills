# Harness adapters

The loop in SKILL.md uses five operations. `scripts/harness.sh` prints which adapter applies
(`desktop`, `cli` or `any`); if you clearly have tools it didn't detect, use the matching column.
State is always the batch dir and git, so the same batch can be foremaned from any harness.

| Operation | Claude Code desktop | Claude Code CLI | Any harness |
|---|---|---|---|
| **spawn** worker | `start_session` (below) | `claude --bg -n "foreman <batch> <id>" "<brief>"` | `agent.sh --bg --cwd <worktree> --log <batch-dir>/<id>.log <batch-dir>/<id>.brief.md` |
| **tell** worker | `SendMessage` to its `local_…` id | `SendMessage` to its address | append to `<batch-dir>/<id>.inbox.md`, then **respawn** it |
| **wake** foreman | `watch.sh` with `run_in_background` | same | `watch.sh` as a background job; if the harness can't wake on exit, run it in the foreground (it returns within `max-min`) |
| **end** worker | `archive_session` | `claude stop <id>` + `claude rm <id>` | `kill <pid>` if alive |
| **subagent** (short read-only job) | Agent tool | Agent tool | `agent.sh --readonly <prompt-file>` |

Always write the brief to `<batch-dir>/<id>.brief.md` before spawning, whatever the adapter: a
respawn reuses it.

## Claude Code desktop

`start_session` with `initiation "user_asked"`, `context "fresh"`, `use_worktree false`, no
`cwd`, `name` = id, `model` if asked, `wake_when_done true`, `prompt` = the brief, `background` =
the batch goal; all launches in one message. Record each session id.
- A `PermissionRequest` hook (matcher `mcp__ccd_session__start_session`, allow) removes the
  approval card per session; doctor checks it.
- The app refuses `start_session` in a turn started by a worker message or an event: an item that
  unblocks there is proposed instead (`initiation "own_initiative"`, same brief).

## Claude Code CLI

Your name: `ListAgents` prints "This session is <name>"; put "Message the foreman with
SendMessage, to: \"<name>\"" in the brief. Launch from the workspace root (a trusted folder),
`--permission-mode` = this session's mode. `claude agents --json` lists workers. No PR auto-fix:
`verify.sh` the `pr_open` items on each wake and tell a red one to fix CI.

## Any harness (agent.sh)

Workers are one-shot headless runs of whatever agent CLI is installed (`AGENT_CMD` overrides:
codex, opencode, gemini, aider, a custom wrapper). They can't receive messages mid-run, so:
- A worker that needs a decision writes its card and exits.
- To answer, append the answer to `<id>.inbox.md` and respawn it in the same worktree. The brief's
  relaunch line plus "Read <id>.inbox.md first" lets it continue from what exists.
- Record `pid` and `log` from `agent.sh --bg` in the item; `kill -0 <pid>` tells you if it is
  alive. A dead pid with a non-final card is `stuck`.
- The worker's closing line goes to its card's `note`; there is no message channel.
- No PR auto-fix: on each wake `verify.sh` the `pr_open` items; respawn a red one with
  "fix CI on <pr>" in its inbox.
