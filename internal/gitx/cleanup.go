package gitx

import (
	"fmt"
	"os"
	"strings"
)

const cleanupUsage = "usage: smithy cleanup <repo> <branch> [<worktree>] [--force]"

// WorktreeOf finds the worktree path that has branch checked out in `git worktree list --porcelain` output.
func WorktreeOf(porcelain, branch string) string {
	w := ""
	for _, l := range strings.Split(porcelain, "\n") {
		if p, ok := strings.CutPrefix(l, "worktree "); ok {
			w = p
		} else if l == "branch refs/heads/"+branch {
			return w
		}
	}
	return ""
}

// CleanupMain runs `smithy cleanup`: removes a finished task's worktree and local branch, and
// prints `cleaned <branch>` or `kept <branch>: <why>` (exit 1 when something was kept).
func CleanupMain(args []string) int {
	if len(args) < 2 {
		fmt.Fprintln(os.Stderr, cleanupUsage)
		return 2
	}
	repo, branch, wt, force := args[0], args[1], "", false
	for _, a := range args[2:] {
		if a == "--force" {
			force = true
		} else {
			wt = a
		}
	}
	if err := os.Chdir(repo); err != nil {
		fmt.Fprintln(os.Stderr, "smithy cleanup:", err)
		return 2
	}
	_ = quiet("git", "fetch", "-q", "--prune", "origin")
	if wt == "" {
		wt = WorktreeOf(git("worktree", "list", "--porcelain"), branch)
	}
	if fi, err := os.Stat(wt); wt != "" && err == nil && fi.IsDir() {
		if !force && git("-C", wt, "status", "--porcelain") != "" {
			fmt.Printf("kept %s: uncommitted changes in %s\n", branch, wt)
			return 1
		}
		ra := []string{"worktree", "remove"}
		if force {
			ra = append(ra, "--force")
		}
		if quiet("git", append(ra, wt)...) != nil {
			fmt.Printf("kept %s: could not remove %s\n", branch, wt)
			return 1
		}
	}
	attached("git", "worktree", "prune")
	if quiet("git", "show-ref", "-q", "--verify", "refs/heads/"+branch) != nil {
		fmt.Println("cleaned", branch)
		return 0
	}
	if git("branch", "--show-current") == branch {
		fmt.Printf("kept %s: it is checked out here\n", branch)
		return 1
	}
	base := git("symbolic-ref", "-q", "--short", "refs/remotes/origin/HEAD")
	if base == "" {
		base = "origin/main"
	}
	unpushed := git("rev-list", branch, "--not", "--remotes")
	if force || quiet("git", "merge-base", "--is-ancestor", branch, base) == nil || unpushed == "" {
		if stderrOnly("git", "branch", "-D", branch) == nil {
			fmt.Println("cleaned", branch)
			return 0
		}
	}
	fmt.Printf("kept %s: has commits not on any remote; push it or pass --force\n", branch)
	return 1
}
