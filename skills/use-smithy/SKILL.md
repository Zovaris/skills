---
name: use-smithy
description: Routes code work to the installed skill that fits (smelt, warden, ledger, scout, tend, hush, simple) and holds their shared rules. Use at the start of building, changing, fixing, reviewing or documenting code in a repo, or when asked which skill to use. Not for chats without code.
---

# use-smithy

<SUBAGENT-STOP>
If you were launched with a task brief (a smelt test agent, a warden worker, a scout or tend
run), skip this skill: your brief already says what to follow.
</SUBAGENT-STOP>

These skills share one way of working. This file says which one fits the moment and how to use
it. User instructions win over this file, and the repo's AGENTS.md / CLAUDE.md win over it too.

## 1 · See what is installed

`smithy <command>` in this skill means `<skill-dir>/scripts/smithy <command>` (`<skill-dir>` is this file's folder); run it by that path, nothing needs to be on PATH.

Run `smithy skills --list` once per session. Only
offer skills that are listed. To use a user-invoked skill yourself, read the SKILL.md path it
prints and follow it: you can't run it as a slash command.

## 2 · Route

| The user wants… | Use | How |
|---|---|---|
| to build, change or fix code | **smelt** | Announce "Using smelt `<route>` `<speed>`" in one line, read smelt's SKILL.md and follow it: no plan → `plan`, a plan, spec or task → `build`, a bug → `debug`. Trivial work is `fast`. Its approval gates still apply. |
| several tasks done at once, or a task list run in parallel | **warden** | Spawns sessions and costs tokens: propose it with the task list and wait for a yes, or tell the user to run `/warden`. |
| a fact, a comparison, "why does X", "can we Y" | **scout** | Model-invoked; read-only; answers with sources. |
| a decision recorded, docs, module READMEs, comment policy, a codebase map, to search past decisions | **ledger** | Model-invoked. Search past decisions with its `search` mode before re-deciding anything. |
| open PRs kept green, rebased, review comments handled; new PRs or labeled issues watched | **tend** | Suggest `/tend <pr>` or `/tend watch [prs\|issues\|all]`; warden launches it for its own PRs. Issues it accepts become task files in `~/.smithy/plans/<repo>/inbox/` for warden. |
| the work done without conversation | **hush** | Only when the user runs `/hush` or asks for no talk. |
| — every reply | **simple** | If installed, write every reply its way unless the user says "normal mode". |

Not installed? Do the work the plain way and, once, mention the skill that would help.

## 3 · Ground rules across skills

- One task list: plans become `NN-<slug>.md` task files (smelt `TASKS.md` format); smelt builds
  them one at a time, warden in parallel. Never keep a second list.
- Waiting on anything external (CI, a PR, a workflow run, new issues) is one `smithy wait`
  call in the background (smelt, warden and tend ship it), never sleep-then-check turns: it
  costs no tokens and returns one line when something happens.
- Evidence over claims: "done", "passes", "fixed" always name the command and its result.
- Commits are atomic in the repo's style, PRs follow its template, finished worktrees and local
  branches are removed (the `smithy commit`, `smithy pr`, `smithy cleanup` commands).
- Decisions that pass ledger's ADR test (hard to reverse, surprising, a real trade-off) go to an ADR. No explanatory code comments: API doc
  comments only, the "why" lives in docs.
- Models come in three tiers per harness (cheap, mid, strong); `smithy route` picks the tier per job
  and `smithy config model <tier>` gives the model. When a tier is unset (exit 3, or `-` from
  smithy route): run `smithy config suggest-models`. If it prints suggestions, propose them in
  one line ("cheap <model>, mid <model>, strong <model> for this harness, ok?") and on a yes run
  `smithy config accept-models`. If it prints none, ask the user to name each tier and save them with
  `smithy config set-model <tier> <name>`. Ask once per harness; until then use the session's model.
  Under `/hush`, don't ask: use the session's model and say so at the end.
- Ask only for decisions that are the user's: scope, money, prod, data, security, irreversible
  actions, pushing, merging. Other decisions that would stop the work: low impact, decide;
  medium, one `smithy consult` call to the user's strong model (smelt, warden, tend ship it; it
  uses the current harness's CLI, no tools); log what was decided and why.

## 4 · Turn repeated work into scripts

Check `scripts/SCRIPTS.md` (or the repo's scripts folder) before writing a one-off command:
reuse what is there. At the end of a task, never in the middle of it, look back: did you run the
same multi-step command more than once, or write a throwaway script (a heredoc, `python -c`,
`node -e`, a long pipeline) the project will need again? Then propose saving them, all in one
line ("Save as scripts: `wait-deploy.sh` (polls the deploy URL), ok?"). On a yes:

- save in the repo's `scripts/` (or where the user says), same language, executable, with a
  usage line, arguments instead of this session's values, secrets from env vars, errors to
  stderr and a non-zero exit;
- add one line to `scripts/SCRIPTS.md`: name, what it does, usage.

Never propose one the user declined, and not under `/hush`. Ideas from
[scriptify](https://github.com/pfcoperez/scriptify).

## 5 · Red flags

| Thought | Reality |
|---|---|
| "Too small for smelt" | That is what `fast` is for: a few minutes, still test-first. |
| "I'll plan it in my head" | Plans live in the task list so warden and the next session can use them. |
| "I'll just ask the user this fact" | Facts are scout's job; ask the user only for decisions. |
| "A comment will explain it" | Put the why in the module README or an ADR. |
| "Done, it should work" | Run it; quote the command and result. |
| "I'll launch warden, it's faster" | It costs sessions: propose it, wait for a yes. |
| "I'll sleep 2 minutes and check CI again" | `smithy wait pr:<n>` in the background: no tokens, no missed finish. |
| "I've typed this pipeline three times" | Propose it as a script at the end of the task. |

## 6 · Settings and setup

All settings live in two JSON files, repo first: `<repo>/.smithy/config.json` (this repo only)
and `~/.smithy/config.json` (the user's defaults). `smithy config list` shows every setting
with its value, where it came from and what uses it; `smithy config set [--repo] <key> <value>`
changes one. Nobody has to edit JSON by hand.

Two ways to fill them:
- **Up front** — when the user says "use-smithy setup" (or `/use-smithy setup`): run
  `smithy setup status`, then ask every unset setting in one message (numbered, each with your
  recommendation, "yes" accepts all), save the answers, and offer the agent-instructions block
  (`smithy setup block add <file>`, only with a yes, after showing `references/AGENTS-BLOCK.md`).
  Then, if `setup status` says smithy is not on PATH, offer once to make `smithy` a terminal
  command for the user (`smithy status`, `smithy tasks board --all`): on a yes,
  `smithy setup path add` (one line in their shell's startup file).
- **On first use** — any skill that needs an unset setting asks just that one, once, and saves
  it: `--repo` when the answer is about this repo (where specs go), user-level otherwise
  (models, merge and cleanup defaults).
