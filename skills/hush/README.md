# hush

Does the task with no talk. No narration between steps, no questions; progress shows in your
harness's task list, and the session ends with one line:

```
done: PR https://github.com/acme/app/pull/42
blocked: the migration needs a production backup first
```

Started by you: `/hush <task>` ([how to start a skill in your harness](../../README.md#harnesses)). It composes with other skills: `/hush /smelt build next`.

- Low-impact choices it makes itself and lists where the work lands (PR body or final line).
- It commits or opens a PR only when the task asks for it.
- It stops only for what is yours alone, with `blocked: <why>`.
