package main

import (
	"fmt"
	"os"

	"github.com/Zovaris/smithy/internal/docs"
)

func init() {
	register("adr", `next numbered ADR (smithy adr "<title>" [adr-dir])`, docs.ADRUsage, "", docs.ADR)
	register("search", "search ADRs, glossary and docs, best sources first", docs.SearchUsage,
		"--adr --glossary --all --max=", docs.Search)
	register("comments", "check the comment policy (smithy comments [paths] | --diff <base>)", docs.CommentsUsage,
		"--diff", commentsMain)
	register("drift", "doc-drift report against a base (smithy drift [base])", docs.DriftUsage, "", docs.Drift)
}

// commentsMain refuses a path that doesn't exist, so a typo can't pass as clean.
func commentsMain(args []string) int {
	if len(args) == 0 || args[0] != "--diff" {
		for _, p := range args {
			if _, err := os.Stat(p); err != nil {
				fmt.Fprintf(os.Stderr, "smithy comments: no such file or directory: %s\n", p)
				return 2
			}
		}
	}
	return docs.Comments(args)
}
