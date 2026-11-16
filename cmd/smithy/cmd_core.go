package main

import (
	"fmt"

	"github.com/Zovaris/smithy/internal/cards"
	"github.com/Zovaris/smithy/internal/config"
	"github.com/Zovaris/smithy/internal/harness"
	"github.com/Zovaris/smithy/internal/names"
	"github.com/Zovaris/smithy/internal/tasks"
	"github.com/Zovaris/smithy/internal/wait"
)

func init() {
	register("config", "settings and models (smithy config list)", config.Main)
	register("harness", `"<harness> <adapter>" for this shell`, func([]string) int {
		h, a := harness.Detect()
		fmt.Println(h, a)
		return 0
	})
	register("names", "branch and worktree names", names.Main)
	register("tasks", "the shared task list (smithy tasks board --all)", tasks.Main)
	register("status", "every task list and batch on this machine", func([]string) int { return tasks.Main([]string{"board", "--all"}) })
	register("cards", "warden status cards", cards.Main)
	register("wait", "wait without tokens for PRs, runs, branches, issues or a batch", wait.Main)
}
