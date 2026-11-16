---
name: playbook
description: How to use the installed Zovaris skills (forge, foreman, docs, scout, tend, silent, direct). Use at the start of any software work — building, changing, fixing, planning, reviewing, investigating, documenting — and whenever the user asks how to work here or which skill to use.
---

# playbook

<SUBAGENT-STOP>
If you were launched with a task brief (a forge test agent, a foreman worker, a scout or tend
run), skip this skill: your brief already says what to follow.
</SUBAGENT-STOP>

These skills share one way of working. This file says which one fits the moment and how to use
it. User instructions win over this file, and the repo's AGENTS.md / CLAUDE.md win over it too.

## 1 · See what is installed

Run `scripts/find-skill.sh --list` once per session (`<skill-dir>` is this file's folder). Only
offer skills that are listed. To use a user-invoked skill yourself, read the SKILL.md path it
prints and follow it: you can't run it as a slash command.

## 2 · Route

| The user wants… | Use | How |
|---|---|---|
| to build, change or fix code | **forge** | Announce "Using forge `<route>` `<speed>`" in one line, read forge's SKILL.md and follow it: no plan → `plan`, a plan, spec or task → `build`, a bug → `debug`. Trivial work is `fast`. Its approval gates still apply. |
| several tasks done at once, or a task list run in parallel | **foreman** | Spawns sessions and costs tokens: propose it with the task list and wait for a yes, or tell the user to run `/foreman`. |
| a fact, a comparison, "why does X", "can we Y" | **scout** | Model-invoked; read-only; answers with sources. |
| a decision recorded, docs, module READMEs, comment policy, a codebase map, to search past decisions | **docs** | Model-invoked. Search `docs search` before re-deciding anything. |
| open PRs kept green, rebased, review comments handled; new PRs or labeled issues watched | **tend** | Suggest `/tend <pr>` or `/tend watch [prs\|issues\|all]`; foreman launches it for its own PRs. Issues it accepts become task files in `~/.agents/plans/<repo>/inbox/` for foreman. |
| the work done without conversation | **silent** | Only when the user runs `/silent` or asks for no talk. |
| — every reply | **direct** | If installed, write every reply its way unless the user says "normal mode". |

Not installed? Do the work the plain way and, once, mention the skill that would help.

## 3 · Ground rules across skills

- One task list: plans become `NN-<slug>.md` task files (forge `TASKS.md` format); forge builds
  them one at a time, foreman in parallel. Never keep a second list.
- Evidence over claims: "done", "passes", "fixed" always name the command and its result.
- Commits are atomic in the repo's style, PRs follow its template, finished worktrees and local
  branches are removed (the `commit.sh`, `pr.sh`, `cleanup.sh` scripts in forge and foreman).
- Decisions that are hard to reverse go to an ADR (docs). No explanatory code comments: API doc
  comments only, the "why" lives in docs.
- Cheap work (scouting, reviews, simple workers) uses the user's cheap model:
  `scripts/config.sh model cheap`. Exit 3 means unset: ask once which cheap and strong models to
  use in this harness and save them with `config.sh set-model`.
- Ask only for decisions that are the user's: scope, money, prod, data, security, irreversible
  actions, pushing, merging.

## 4 · Red flags

| Thought | Reality |
|---|---|
| "Too small for forge" | That is what `fast` is for: a few minutes, still test-first. |
| "I'll plan it in my head" | Plans live in the task list so foreman and the next session can use them. |
| "I'll just ask the user this fact" | Facts are scout's job; ask the user only for decisions. |
| "A comment will explain it" | Put the why in the module README or an ADR. |
| "Done, it should work" | Run it; quote the command and result. |
| "I'll launch foreman, it's faster" | It costs sessions: propose it, wait for a yes. |

## 5 · Settings and setup

All settings live in two JSON files, repo first: `<repo>/.agents/config.json` (this repo only)
and `~/.agents/config.json` (the user's defaults). `scripts/config.sh list` shows every setting
with its value, where it came from and what uses it; `config.sh set [--repo] <key> <value>`
changes one. Nobody has to edit JSON by hand.

Two ways to fill them:
- **Up front** — when the user says "playbook setup" (or `/playbook setup`): run
  `scripts/setup.sh status`, then ask every unset setting in one message (numbered, each with your
  recommendation, "yes" accepts all), save the answers, and offer the agent-instructions block
  (`setup.sh block add <file>`, only with a yes, after showing `references/AGENTS-BLOCK.md`).
- **On first use** — any skill that needs an unset setting asks just that one, once, and saves
  it: `--repo` when the answer is about this repo (where specs go), user-level otherwise
  (models, merge and cleanup defaults).
