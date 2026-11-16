package main

import "github.com/Zovaris/skills/internal/gitx"

func init() {
	register("commit", "atomic commits in the repo's message style", gitx.CommitMain)
	register("pr", "pull requests that follow the repo's PR template", gitx.PRMain)
	register("cleanup", "remove a finished task's worktree and local branch", gitx.CleanupMain)
	register("verify", "proof for a worker's PR claim", gitx.VerifyMain)
	register("pr-state", "compact JSON state of one PR (tend)", gitx.PRStateMain)
}
