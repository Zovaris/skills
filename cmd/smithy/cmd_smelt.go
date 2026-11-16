package main

import "github.com/Zovaris/skills/internal/plan"

func init() {
	register("stack", "the repo's test tooling as key: value lines", plan.StackMain)
	register("changed", "source files changed against a base (--csv for Stryker)", plan.ChangedMain)
	register("guard-tests", "pre-edit hook: blocks test edits in the green phase", plan.GuardMain)
	register("task-dir", "resolve and create the task dir for a plan slug", plan.TaskDirMain)
}
