package proof

import (
	"bytes"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
)

func git(t *testing.T, dir string, args ...string) {
	t.Helper()
	cmd := exec.Command("git", append([]string{"-C", dir, "-c", "user.email=t@t", "-c", "user.name=t", "-c", "init.defaultBranch=main"}, args...)...)
	if out, err := cmd.CombinedOutput(); err != nil {
		t.Fatalf("git %v: %v\n%s", args, err, out)
	}
}

func newRepo(t *testing.T) string {
	t.Helper()
	dir, err := filepath.EvalSymlinks(t.TempDir())
	if err != nil {
		t.Fatal(err)
	}
	git(t, dir, "init", "-q")
	if err := os.WriteFile(filepath.Join(dir, "a.txt"), []byte("a\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	git(t, dir, "add", "a.txt")
	git(t, dir, "commit", "-q", "-m", "init")
	return dir
}

func TestRunRecordsExitDigestAndCommit(t *testing.T) {
	dir := newRepo(t)
	var out bytes.Buffer
	r, err := Run(dir, "suite passes", []string{"sh", "-c", "echo hi; exit 3"}, &out)
	if err != nil {
		t.Fatal(err)
	}
	if r.Exit != 3 || out.String() != "hi\n" || r.Claim != "suite passes" || r.Dirty || len(r.Digest) != 16 || len(r.Commit) != 40 {
		t.Fatalf("bad receipt %+v out=%q", r, out.String())
	}
	r2, _ := Run(dir, "", []string{"sh", "-c", "echo hi; exit 3"}, &bytes.Buffer{})
	if r2.Digest != r.Digest || r2.Claim != "sh -c echo hi; exit 3" {
		t.Fatalf("digest not stable or default claim wrong: %+v", r2)
	}
}

func TestRunMarksDirtyTreeAndStale(t *testing.T) {
	dir := newRepo(t)
	if err := os.WriteFile(filepath.Join(dir, "a.txt"), []byte("b\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	r, _ := Run(dir, "x", []string{"true"}, &bytes.Buffer{})
	if !r.Dirty || r.Fresh(r.Commit) {
		t.Fatalf("dirty tree should give a stale receipt: %+v", r)
	}
}

func TestAppendLoadMarkdown(t *testing.T) {
	dir := newRepo(t)
	a := Receipt{Claim: "a|b", Command: []string{"go", "test"}, Exit: 0, Commit: "1111111111", Digest: "d"}
	b := Receipt{Claim: "lint", Command: []string{"lint"}, Exit: 1, Commit: "2222222222", Digest: "e"}
	for _, r := range []Receipt{a, b} {
		if err := Append(dir, r); err != nil {
			t.Fatal(err)
		}
	}
	rs, err := Load(dir)
	if err != nil || len(rs) != 2 {
		t.Fatalf("load: %v %v", rs, err)
	}
	md := Markdown(rs, "1111111111")
	if !strings.Contains(md, `| a\|b | `+"`go test`"+` | 0 | 1111111 |`) || !strings.Contains(md, "2222222 (stale)") {
		t.Fatalf("markdown:\n%s", md)
	}
}

func TestLoadMissingIsEmpty(t *testing.T) {
	rs, err := Load(t.TempDir())
	if err != nil || rs != nil {
		t.Fatalf("got %v %v", rs, err)
	}
}

func TestScanDiffFindsSecretsOnAddedLinesOnly(t *testing.T) {
	diff := strings.Join([]string{
		"+++ b/app/config.go",
		"@@ -1,0 +10,4 @@",
		`+key := "AKIAABCDEFGHIJKLMNOP"`, // smithy:allow (fixture)
		`+password = "hunter2hunter2"`,   // smithy:allow (fixture)
		`+password = os.Getenv("PASSWORD")`,
		`+token := "ghp_` + strings.Repeat("a", 36) + `" // smithy:allow`,
		"-old := \"AKIAABCDEFGHIJKLMNOP\"", // smithy:allow (fixture)
		"+++ b/README.md",
		"@@ -5 +7 @@",
		"+postgres://admin:supersecret@db:5432/x", // smithy:allow (fixture)
	}, "\n")
	fs := ScanDiff(diff)
	var got []string
	for _, f := range fs {
		got = append(got, f.String())
	}
	want := []string{
		"app/config.go:10\taws access key\tAKIA************MNOP",
		"app/config.go:11\thardcoded secret\tpass*******************er2\"",
		"README.md:7\tcredentials in url\tpost*********************ret@",
	}
	if strings.Join(got, "\n") != strings.Join(want, "\n") {
		t.Fatalf("got:\n%s\nwant:\n%s", strings.Join(got, "\n"), strings.Join(want, "\n"))
	}
}

func TestScanFiles(t *testing.T) {
	fs := ScanFiles([]string{".env", "deploy/.env.production", ".env.example", "certs/server.pem", "src/key.go", "id_ed25519", ""})
	var got []string
	for _, f := range fs {
		got = append(got, f.File)
	}
	if strings.Join(got, ",") != ".env,deploy/.env.production,certs/server.pem,id_ed25519" {
		t.Fatalf("got %v", got)
	}
}

func TestMask(t *testing.T) {
	if mask("abc") != "***" || mask("abcdefghij") != "abcd**ghij" {
		t.Fatal(mask("abcdefghij"))
	}
}

func TestMainsEndToEnd(t *testing.T) {
	dir := newRepo(t)
	t.Chdir(dir)
	if c := ReceiptMain([]string{"run", "--claim", "ok", "--", "true"}); c != 0 {
		t.Fatalf("run exit %d", c)
	}
	if c := ReceiptMain([]string{"run", "--", "false"}); c != 1 {
		t.Fatalf("run should pass the exit code through, got %d", c)
	}
	for _, a := range [][]string{{"list"}, {"list", "--md", "--all"}} {
		if c := ReceiptMain(a); c != 0 {
			t.Fatalf("%v exit %d", a, c)
		}
	}
	if c := ReceiptMain([]string{"list", "--bogus"}); c != 2 {
		t.Fatalf("bad flag exit %d", c)
	}
	if c := ReceiptMain([]string{"run", "--"}); c != 2 {
		t.Fatalf("no command exit %d", c)
	}
	if c := ReceiptMain([]string{"clear"}); c != 0 {
		t.Fatalf("clear exit %d", c)
	}
	if rs, _ := Load(dir); len(rs) != 0 {
		t.Fatalf("clear left %v", rs)
	}
	if c := ScanMain(nil); c != 0 {
		t.Fatalf("clean scan exit %d", c)
	}
	if err := os.WriteFile(filepath.Join(dir, "a.txt"), []byte("-----BEGIN RSA PRIVATE KEY-----\n"), 0o644); err != nil { // smithy:allow
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(dir, ".env"), []byte("X=1\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	if c := ScanMain([]string{"--base", "HEAD"}); c != 1 {
		t.Fatalf("dirty scan exit %d", c)
	}
	if c := ScanMain([]string{"--nope"}); c != 2 {
		t.Fatalf("bad flag exit %d", c)
	}
}
