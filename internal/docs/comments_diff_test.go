package docs

import (
	"io"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func capture(t *testing.T, f func() int) (string, int) {
	t.Helper()
	r, w, err := os.Pipe()
	if err != nil {
		t.Fatal(err)
	}
	stdout := os.Stdout
	os.Stdout = w
	defer func() { os.Stdout = stdout }()
	done := make(chan []byte)
	go func() {
		b, _ := io.ReadAll(r)
		done <- b
	}()
	code := f()
	w.Close()
	return string(<-done), code
}

func repoWithOddNames(t *testing.T) string {
	t.Helper()
	dir, err := filepath.EvalSymlinks(t.TempDir())
	if err != nil {
		t.Fatal(err)
	}
	gitIn(t, dir, "init", "-q")
	commitFile(t, dir, "a.txt", "a\n")
	bad := "package b\n\nfunc helper() int {\n\t// internal note\n\treturn 1\n}\n"
	commitFile(t, dir, "with space.go", bad)
	commitFile(t, dir, "ñandú.go", bad)
	return dir
}

func TestCommentsDiffOddNames(t *testing.T) {
	dir := repoWithOddNames(t)
	t.Chdir(dir)
	out, code := capture(t, func() int { return Comments([]string{"--diff", "HEAD~2"}) })
	if code != 1 || !strings.Contains(out, "with space.go:4:") || !strings.Contains(out, "ñandú.go:4:") {
		t.Fatalf("code %d, out:\n%s", code, out)
	}
}

func TestCommentsDiffBadBase(t *testing.T) {
	t.Chdir(repoWithOddNames(t))
	for _, base := range []string{"nosuch", "--output=x"} {
		if _, code := capture(t, func() int { return Comments([]string{"--diff", base}) }); code != 2 {
			t.Errorf("base %q: code %d, want 2", base, code)
		}
	}
}
