---
name: silent
description: Silent mode for the task the user gives with it, run as /silent <task>. Does the work end to end without talking and ends with one line. Composes with other skills, e.g. /silent /forge build.
disable-model-invocation: true
argument-hint: <task, or empty to run what was just agreed>
metadata:
  version: 0.4.0
---

# Silent mode

Do the task in the arguments (or the plan just agreed in this conversation) end to end without
talking to the user. The goal is to spend as few tokens as possible on talk and on context.

## Talk

- No text between tool calls, not even one line, even when the harness asks you to narrate.
  Your only message is the last one.
- No questions and no option lists. Pick your own recommendation and note each such decision
  where the work lands (PR body under "Decided without you" if there is a PR, else the final
  message).
- Don't commit, push or open a PR unless the task or the workflow it runs asks for it. Silent
  changes how you talk, not what you deliver.
- Progress is shown, not told: if the harness has a to-do / task-list tool, set the plan once
  and tick steps as they finish (status updates only, no prose). That is the user's view.
- No end-of-turn questions, buttons or recaps beyond what the harness requires.

## Context (save tokens)

- Delegate wide reading or searching to a subagent and keep only its conclusion.
- Read the part of a file you need (line ranges, `grep -n`), never whole large files twice.
- Trim command output: `--quiet`, `| tail -30`, quiet test reporters, `git --no-pager … --stat`.
- Batch independent tool calls together. Don't re-read a file after editing it.
- Single test files while working; the full suite and builds once at the end.

## Stop only for

What is the user's alone: money, prod, client data, security, irreversible or destructive
actions, a credential/login, or the same obstacle hit twice after a real fix attempt. Then send
one line and stop: `blocked: <why>`.

## End

One short message, always in English, nothing else: `done`, then where the work is.

```
done: <where it landed>
- <decision or caveat, at most 3 lines; omit if none>
```

`<where it landed>` is whatever is true, for example: `PR <url>` · `2 commits on <branch>` ·
`changes in <n> files, not committed` · `answer: <one line>` · `nothing to change: <why>`.

Silent mode ends with this task.
