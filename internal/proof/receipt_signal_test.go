//go:build !windows

package proof

import (
	"errors"
	"io"
	"os"
	"path/filepath"
	"syscall"
	"testing"
	"time"
)

func TestReceiptNotWrittenFailsASuccess(t *testing.T) {
	dir := newRepo(t)
	t.Chdir(dir)
	if err := os.WriteFile(filepath.Join(dir, ".smelt"), []byte("x"), 0o644); err != nil {
		t.Fatal(err)
	}
	if c := ReceiptMain([]string{"run", "--", "true"}); c != 1 {
		t.Fatalf("unrecorded success exit %d", c)
	}
	if c := ReceiptMain([]string{"run", "--", "sh", "-c", "exit 3"}); c != 3 {
		t.Fatalf("failed command exit %d", c)
	}
}

func TestReceiptRecordsSignal(t *testing.T) {
	dir := newRepo(t)
	r, err := Run(dir, "", []string{"sh", "-c", "kill -9 $$"}, io.Discard)
	if err != nil {
		t.Fatal(err)
	}
	if r.Exit != 137 {
		t.Fatalf("exit %d", r.Exit)
	}
}

func TestReceiptForwardsTermAndWritesNothing(t *testing.T) {
	dir := newRepo(t)
	go func() {
		time.Sleep(300 * time.Millisecond)
		syscall.Kill(os.Getpid(), syscall.SIGTERM)
	}()
	start := time.Now()
	_, err := Run(dir, "", []string{"sleep", "5"}, io.Discard)
	var in *Interrupted
	if !errors.As(err, &in) || in.Code != 143 {
		t.Fatalf("err %v", err)
	}
	if time.Since(start) > 3*time.Second {
		t.Fatal("child was not stopped")
	}
}
