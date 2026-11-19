package gitx

import (
	"fmt"
	"strings"

	"github.com/Zovaris/smithy/internal/ghx"
)

// EmptyTree is git's empty tree object: a base that diffs against the whole history.
const EmptyTree = "4b825dc642cb6eb9a060e54bf8d69288fbee4904"

func branchName(s string) bool { return s != "HEAD" && !strings.ContainsAny(s, "~^:@{ ") }

// ResolveBase returns the commit to diff against and a label for it, for the repo at root.
// A branch name means its merge-base with origin/<branch> when that ref exists, a revision
// expression is used as given, and "" means origin's default branch (else the upstream, else
// the whole history).
func ResolveBase(root, base string) (sha, label string) {
	ref := ""
	switch {
	case base == "":
		if r, err := ghx.Run("git", "-C", root, "symbolic-ref", "--quiet", "--short", "refs/remotes/origin/HEAD"); err == nil && r != "" {
			ref = r
		}
	case branchName(base) && !strings.HasPrefix(base, "origin/"):
		if _, err := ghx.Run("git", "-C", root, "rev-parse", "--verify", "--quiet", "refs/remotes/origin/"+base); err == nil {
			ref = "origin/" + base
		}
	}
	if ref == "" && base == "" {
		if up, err := ghx.Run("git", "-C", root, "rev-parse", "--abbrev-ref", "--symbolic-full-name", "@{upstream}"); err == nil && up != "" {
			ref = up
		} else {
			return EmptyTree, "the whole history (no origin default branch or upstream found)"
		}
	}
	if ref == "" && !branchName(base) {
		return base, base
	}
	if ref == "" {
		ref = base
	}
	mb, err := ghx.Run("git", "-C", root, "merge-base", "HEAD", ref)
	if err != nil || mb == "" {
		return ref, ref + " (no merge-base with HEAD)"
	}
	return mb, fmt.Sprintf("%s (merge-base %s)", ref, shortSHA(mb))
}

func shortSHA(s string) string {
	if len(s) > 7 {
		return s[:7]
	}
	return s
}
