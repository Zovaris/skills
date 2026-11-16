package docs

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func write(t *testing.T, p, body string) {
	t.Helper()
	if err := os.MkdirAll(filepath.Dir(p), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(p, []byte(body), 0o644); err != nil {
		t.Fatal(err)
	}
}

func TestSearchRanking(t *testing.T) {
	t.Chdir(t.TempDir())
	write(t, "docs/adr/0001-events.md", "# 0001\nWe store every Invoice event.\n")
	write(t, "docs/GLOSSARY.md", "**Invoice** — a bill.\n")
	write(t, "src/billing/README.md", "Invoice totals.\n")
	write(t, "node_modules/x/README.md", "invoice\n")
	write(t, "docs/how-to/regen.md", "Regenerate an invoice.\n")
	write(t, "README.md", "invoices live in billing\n")
	var all []string
	for _, g := range [][]string{SearchADRs(), SearchGlossary(), SearchModules(), SearchOthers()} {
		all = append(all, SearchHits("INVOICE", g)...)
	}
	want := []string{
		"docs/adr/0001-events.md:2:We store every Invoice event.",
		"docs/GLOSSARY.md:1:**Invoice** — a bill.",
		"src/billing/README.md:1:Invoice totals.",
		"README.md:1:invoices live in billing",
		"docs/how-to/regen.md:1:Regenerate an invoice.",
	}
	if strings.Join(all, "\n") != strings.Join(want, "\n") {
		t.Errorf("got\n%s\nwant\n%s", strings.Join(all, "\n"), strings.Join(want, "\n"))
	}
}
