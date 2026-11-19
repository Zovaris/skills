package plan

import (
	"path/filepath"
	"testing"
)

func TestStackBaseWithoutOriginHead(t *testing.T) {
	remote := t.TempDir()
	git(t, remote, "init", "-q", "--bare")
	dir := newRepo(t)
	git(t, dir, "remote", "add", "origin", remote)
	git(t, dir, "push", "-q", "origin", "HEAD:main")
	if got := stackMap(Stack(dir))["base"]; got != "main" {
		t.Errorf("base = %q, want main", got)
	}
}

func TestStackGoTestSkipsCache(t *testing.T) {
	dir := newRepo(t)
	write(t, filepath.Join(dir, "go.mod"), "module x\n")
	if got := stackMap(Stack(dir))["test"]; got != "go test -count=1 ./..." {
		t.Errorf("test = %q", got)
	}
}
