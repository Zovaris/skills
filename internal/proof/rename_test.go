package proof

import (
	"os"
	"path/filepath"
	"testing"
)

func TestScanCatchesFileRenamedToSecretName(t *testing.T) {
	dir := newRepo(t)
	t.Chdir(dir)
	if err := os.WriteFile(filepath.Join(dir, "README"), []byte("hello there, a plain readme\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	git(t, dir, "add", "README")
	git(t, dir, "commit", "-q", "-m", "readme")
	git(t, dir, "mv", "README", ".env")
	git(t, dir, "commit", "-q", "-m", "rename")
	if c := ScanMain([]string{"--base", "HEAD~1"}); c != 1 {
		t.Fatalf("renamed .env passed: exit %d", c)
	}
}
