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
| open PRs kept green, rebased, review comments handled | **tend** | Suggest `/tend <pr>`; foreman launches it for its own PRs. |
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

## 5 · Setup (`/playbook setup` or when asked)

`scripts/setup.sh status` shows installed skills, model settings and whether the agent
instructions block is present. `scripts/setup.sh block add <file>` adds a short block to the
user's AGENTS.md / CLAUDE.md that points every session here; only with the user's yes, and
show the block first (`references/AGENTS-BLOCK.md`).
