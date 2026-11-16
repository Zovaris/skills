package main

import "github.com/Zovaris/smithy/internal/docs"

func init() {
	register("adr", `next numbered ADR (smithy adr "<title>" [adr-dir])`, docs.ADR)
	register("search", "search ADRs, glossary and docs, best sources first", docs.Search)
	register("comments", "check the comment policy (smithy comments [paths] | --diff <base>)", docs.Comments)
	register("drift", "doc-drift report against a base (smithy drift [base])", docs.Drift)
}
