---
name: hush
description: Runs the given task end to end with no narration and ends with a short done line. Invoked as /hush <task>; composes with other skills, e.g. /hush /smelt build.
disable-model-invocation: true
argument-hint: <task, or empty to run what was just agreed>
---

# Hush mode

Do the task in the arguments (or the plan just agreed in this conversation) end to end without
talking to the user. The goal is to spend as few tokens as possible on talk and on context.

## Talk

- No text between tool calls, not even one line: no "Now let me…", "Next I'll…", "Good, that
  works" or step summaries, even when the harness asks you to narrate. This holds for the whole
  session, however long it gets. Your only message is the last one.
- No questions and no option lists (the only exception is the `blocked:` line below). Pick your own recommendation and note each such decision
  where the work lands (PR body under "Decided without you" if there is a PR, else the final
  message).
- Don't commit, push or open a PR unless the task or the workflow it runs asks for it. Hush
  changes how you talk, not what you deliver.
- Progress is shown, not told: if the harness has a to-do / task-list tool, set the plan once
  and tick steps as they finish (status updates only, no prose), with no end-of-turn questions,
  buttons or recaps beyond what the harness requires.

## Context (save tokens)

- Delegate wide reading or searching to a subagent and keep only its conclusion.
- Read the part of a file you need (line ranges, `grep -n`), never whole large files twice.
- Trim command output: `--quiet`, `| tail -30`, quiet test reporters, `git --no-pager … --stat`.
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

Hush mode ends with this task.
