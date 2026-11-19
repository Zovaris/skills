package docs

import (
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
)

func gitIn(t *testing.T, dir string, args ...string) {
	t.Helper()
	cmd := exec.Command("git", append([]string{"-C", dir, "-c", "user.email=t@t", "-c", "user.name=t", "-c", "init.defaultBranch=main"}, args...)...)
	if out, err := cmd.CombinedOutput(); err != nil {
		t.Fatalf("git %v: %v\n%s", args, err, out)
	}
}

func commitFile(t *testing.T, dir, name, text string) {
	t.Helper()
	if err := os.WriteFile(filepath.Join(dir, name), []byte(text), 0o644); err != nil {
		t.Fatal(err)
	}
	gitIn(t, dir, "add", name)
	gitIn(t, dir, "commit", "-q", "-m", name)
}

// staleCloneOnFeature returns a clone whose local main lags origin/main by one commit (up.go)
// and whose feature branch, cut from origin/main, adds feat.go.
func staleCloneOnFeature(t *testing.T) string {
	t.Helper()
	up, err := filepath.EvalSymlinks(t.TempDir())
	if err != nil {
		t.Fatal(err)
	}
	gitIn(t, up, "init", "-q")
	commitFile(t, up, "a.txt", "a\n")
	dir := filepath.Join(t.TempDir(), "c")
	gitIn(t, up, "clone", "-q", up, dir)
	commitFile(t, up, "up.go", "package x\n\nfunc Upstream() {}\n")
	gitIn(t, dir, "fetch", "-q")
	gitIn(t, dir, "switch", "-q", "-c", "feat", "origin/main")
	commitFile(t, dir, "feat.go", "package x\n\nfunc Feature() {}\n")
	return dir
}

func runDrift(t *testing.T, dir string, args ...string) string {
	t.Helper()
	t.Chdir(dir)
	r, w, err := os.Pipe()
	if err != nil {
		t.Fatal(err)
	}
	stdout := os.Stdout
	os.Stdout = w
	Drift(args)
	os.Stdout = stdout
	w.Close()
	out, _ := io.ReadAll(r)
	return string(out)
}

// A stale local main must not pull already-merged upstream changes into the drift report.
func TestDriftBranchBaseUsesOrigin(t *testing.T) {
	out := runDrift(t, staleCloneOnFeature(t), "main")
	if !strings.Contains(out, "base: origin/main (merge-base ") {
		t.Fatalf("base not resolved to origin/main:\n%s", out)
	}
	if strings.Contains(out, "up.go") || !strings.Contains(out, "feat.go: Feature") {
		t.Fatalf("diffed against the stale local main:\n%s", out)
	}
}

// No base means origin's default branch, labelled the way smithy scan labels it.
func TestDriftDefaultBaseIsOriginDefaultBranch(t *testing.T) {
	out := runDrift(t, staleCloneOnFeature(t))
	if !strings.Contains(out, "base: origin/main (merge-base ") || strings.Contains(out, "up.go") {
		t.Fatalf("default base:\n%s", out)
	}
}
