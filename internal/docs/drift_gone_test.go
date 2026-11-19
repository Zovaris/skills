package docs

import (
	"path/filepath"
	"strings"
	"testing"
)

func TestDriftReportsRenamedSymbolInDocs(t *testing.T) {
	dir, err := filepath.EvalSymlinks(t.TempDir())
	if err != nil {
		t.Fatal(err)
	}
	gitIn(t, dir, "init", "-q")
	commitFile(t, dir, "store.go", "package x\n\ntype Store struct{}\n\nfunc (s *Store) Put() {}\n")
	commitFile(t, dir, "README.md", "Call `Store.Put` to save; `Put` is cheap. Use `git` and `Store`.\n")
	gitIn(t, dir, "branch", "base")
	commitFile(t, dir, "store.go", "package x\n\ntype Store struct{}\n\nfunc (s *Store) Save() {}\n")
	out := runDrift(t, dir, "base")
	sec := out[strings.Index(out, "## Missing references"):strings.Index(out, "## Public API")]
	for _, want := range []string{"README.md: symbol `Store.Put`", "README.md: symbol `Put`"} {
		if !strings.Contains(sec, want) {
			t.Errorf("missing %q in:\n%s", want, sec)
		}
	}
	if strings.Contains(sec, "`Store`") || strings.Contains(sec, "`git`") {
		t.Errorf("flagged a symbol that still exists:\n%s", sec)
	}
}
