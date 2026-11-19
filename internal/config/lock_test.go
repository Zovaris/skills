package config

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

func TestStaleLockDeadPidReclaimed(t *testing.T) {
	e := setup(t)
	os.MkdirAll(filepath.Dir(e.user), 0o755)
	write(t, e.user+".lock", "999999999\n")
	start := time.Now()
	if err := Set(e.user, "k", "v"); err != nil {
		t.Fatal(err)
	}
	if time.Since(start) > 5*time.Second {
		t.Fatal("waited for a dead lock")
	}
	if _, err := os.Stat(e.user + ".lock"); !os.IsNotExist(err) {
		t.Fatal("lock left behind")
	}
}

func TestStaleLockOldReclaimed(t *testing.T) {
	e := setup(t)
	os.MkdirAll(filepath.Dir(e.user), 0o755)
	write(t, e.user+".lock", "")
	old := time.Now().Add(-time.Minute)
	os.Chtimes(e.user+".lock", old, old)
	if err := Set(e.user, "k", "v"); err != nil {
		t.Fatal(err)
	}
}

func TestLockHoldsPid(t *testing.T) {
	e := setup(t)
	var got string
	withLock(e.user, func() error {
		b, _ := os.ReadFile(e.user + ".lock")
		got = strings.TrimSpace(string(b))
		return nil
	})
	if got == "" {
		t.Fatal("no pid in lock")
	}
}

func TestSetKeepsSymlink(t *testing.T) {
	e := setup(t)
	os.MkdirAll(filepath.Dir(e.user), 0o755)
	target := filepath.Join(t.TempDir(), "real.json")
	write(t, target, "{}")
	if err := os.Symlink(target, e.user); err != nil {
		t.Fatal(err)
	}
	if err := Set(e.user, "k", "v"); err != nil {
		t.Fatal(err)
	}
	fi, _ := os.Lstat(e.user)
	if fi.Mode()&os.ModeSymlink == 0 {
		t.Fatal("symlink replaced")
	}
	b, _ := os.ReadFile(target)
	if !strings.Contains(string(b), `"k"`) {
		t.Fatalf("target not written: %s", b)
	}
}

func TestSetReadOnlyRefused(t *testing.T) {
	e := setup(t)
	write(t, e.user, "{}")
	os.Chmod(e.user, 0o444)
	_, se, code := capture(t, func() int { return Main([]string{"set", "k", "v"}) })
	if code != 1 || !strings.Contains(se, "read-only") {
		t.Fatalf("code %d err %q", code, se)
	}
	b, _ := os.ReadFile(e.user)
	if string(b) != "{}" {
		t.Fatalf("rewritten: %s", b)
	}
}

func TestSetKeepsMode(t *testing.T) {
	e := setup(t)
	write(t, e.user, "{}")
	os.Chmod(e.user, 0o640)
	if err := Set(e.user, "k", "v"); err != nil {
		t.Fatal(err)
	}
	fi, _ := os.Stat(e.user)
	if fi.Mode().Perm() != 0o640 {
		t.Fatalf("mode %v", fi.Mode().Perm())
	}
}
