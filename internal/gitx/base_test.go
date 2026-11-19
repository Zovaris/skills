package gitx

import (
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

func commitFile(t *testing.T, dir, name string) {
	t.Helper()
	if err := os.WriteFile(filepath.Join(dir, name), []byte(name+"\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	gitIn(t, dir, "add", name)
	gitIn(t, dir, "commit", "-q", "-m", name)
}

func TestResolveBasePrefersOrigin(t *testing.T) {
	up, err := filepath.EvalSymlinks(t.TempDir())
	if err != nil {
		t.Fatal(err)
	}
	gitIn(t, up, "init", "-q")
	commitFile(t, up, "a.txt")
	dir := filepath.Join(t.TempDir(), "c")
	gitIn(t, up, "clone", "-q", up, dir)
	commitFile(t, up, "b.txt")
	gitIn(t, dir, "fetch", "-q")
	gitIn(t, dir, "switch", "-q", "-c", "feat", "origin/main")
	sha, label := ResolveBase(dir, "main")
	want, _ := exec.Command("git", "-C", dir, "rev-parse", "origin/main").Output()
	if sha != strings.TrimSpace(string(want)) || !strings.HasPrefix(label, "origin/main (merge-base ") {
		t.Fatalf("main: %s %q", sha, label)
	}
	if _, label := ResolveBase(dir, ""); !strings.HasPrefix(label, "origin/main (merge-base ") {
		t.Fatalf("default: %q", label)
	}
	if sha, label := ResolveBase(dir, "HEAD~1"); sha != "HEAD~1" || label != "HEAD~1" {
		t.Fatalf("revision not used as given: %s %q", sha, label)
	}
}

func TestResolveBaseWithoutRemoteIsWholeHistory(t *testing.T) {
	dir, err := filepath.EvalSymlinks(t.TempDir())
	if err != nil {
		t.Fatal(err)
	}
	gitIn(t, dir, "init", "-q")
	commitFile(t, dir, "a.txt")
	if sha, _ := ResolveBase(dir, ""); sha != EmptyTree {
		t.Fatalf("no origin, no upstream: %s", sha)
	}
}
