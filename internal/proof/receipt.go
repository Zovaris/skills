// Package proof records fresh evidence for claims (receipts) and checks a diff for secrets
// before it leaves the machine (scan).
package proof

import (
	"bufio"
	"bytes"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strings"
	"time"

	"github.com/Zovaris/smithy/internal/ghx"
)

const receiptUsage = `usage:
  smithy receipt run [--claim "<claim>"] -- <command> [args...]
      runs the command in the repo root, streams its output and records a receipt:
      claim, command, exit code, output digest, commit, dirty tree, duration, platform.
      Exits with the command's exit code.
  smithy receipt list [--md] [--all]
      receipts for the current commit (--all: every commit); --md prints a table for a PR body.
      A receipt taken on another commit or on a dirty tree is marked stale.
  smithy receipt clear
Receipts live in <repo>/.smelt/receipts.jsonl (keep .smelt/ in .gitignore).`

// Receipt is one recorded run of a command, the evidence behind a claim.
type Receipt struct {
	Claim    string   `json:"claim"`
	Command  []string `json:"command"`
	Exit     int      `json:"exit"`
	Digest   string   `json:"digest"`
	Commit   string   `json:"commit"`
	Dirty    bool     `json:"dirty"`
	At       string   `json:"at"`
	Millis   int64    `json:"ms"`
	Platform string   `json:"platform"`
}

// Fresh reports whether r proves something about the tree at head: same commit, clean tree.
func (r Receipt) Fresh(head string) bool { return r.Commit == head && !r.Dirty }

func receiptsPath(root string) string { return filepath.Join(root, ".smelt", "receipts.jsonl") }

func head(root string) (string, bool) {
	sha, _ := ghx.Run("git", "-C", root, "rev-parse", "HEAD")
	st, _ := ghx.Run("git", "-C", root, "status", "--porcelain", "--untracked-files=no")
	return sha, st != ""
}

// Run executes argv in root, tees its output to out and returns the receipt.
func Run(root, claim string, argv []string, out io.Writer) (Receipt, error) {
	cmd := exec.Command(argv[0], argv[1:]...)
	cmd.Dir = root
	h := sha256.New()
	w := io.MultiWriter(out, h)
	cmd.Stdout, cmd.Stderr = w, w
	start := time.Now()
	err := cmd.Run()
	exit := 0
	if err != nil {
		ee, ok := err.(*exec.ExitError)
		if !ok {
			return Receipt{}, err
		}
		exit = ee.ExitCode()
	}
	sha, dirty := head(root)
	if claim == "" {
		claim = strings.Join(argv, " ")
	}
	return Receipt{
		Claim: claim, Command: argv, Exit: exit,
		Digest: hex.EncodeToString(h.Sum(nil))[:16], Commit: sha, Dirty: dirty,
		At: start.UTC().Format(time.RFC3339), Millis: time.Since(start).Milliseconds(),
		Platform: runtime.GOOS + "/" + runtime.GOARCH,
	}, nil
}

// Append adds r to the repo's receipt log.
func Append(root string, r Receipt) error {
	p := receiptsPath(root)
	if err := os.MkdirAll(filepath.Dir(p), 0o755); err != nil {
		return err
	}
	f, err := os.OpenFile(p, os.O_CREATE|os.O_APPEND|os.O_WRONLY, 0o644)
	if err != nil {
		return err
	}
	defer f.Close()
	b, _ := json.Marshal(r)
	_, err = f.Write(append(b, '\n'))
	return err
}

// Load reads every receipt in the repo's log; a missing log is empty.
func Load(root string) ([]Receipt, error) {
	b, err := os.ReadFile(receiptsPath(root))
	if os.IsNotExist(err) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	var rs []Receipt
	sc := bufio.NewScanner(bytes.NewReader(b))
	sc.Buffer(make([]byte, 1<<20), 1<<20)
	for sc.Scan() {
		var r Receipt
		if json.Unmarshal(sc.Bytes(), &r) == nil {
			rs = append(rs, r)
		}
	}
	return rs, nil
}

// Markdown renders receipts as a PR-body table, newest claim last.
func Markdown(rs []Receipt, head string) string {
	var b strings.Builder
	b.WriteString("| Claim | Command | Exit | Commit | Output sha256 |\n|---|---|---|---|---|\n")
	for _, r := range rs {
		c := short(r.Commit)
		if !r.Fresh(head) {
			c += " (stale)"
		}
		fmt.Fprintf(&b, "| %s | `%s` | %d | %s | %s |\n",
			cell(r.Claim), cell(strings.Join(r.Command, " ")), r.Exit, c, r.Digest)
	}
	return b.String()
}

func short(s string) string {
	if len(s) > 7 {
		return s[:7]
	}
	return s
}

func cell(s string) string { return strings.ReplaceAll(strings.ReplaceAll(s, "|", `\|`), "\n", " ") }

// ReceiptMain runs `smithy receipt`.
func ReceiptMain(args []string) int {
	cwd, _ := os.Getwd()
	root := ghx.RepoRoot(cwd)
	if len(args) == 0 {
		fmt.Fprintln(os.Stderr, receiptUsage)
		return 2
	}
	if root == "" {
		fmt.Fprintln(os.Stderr, "receipt: not inside a git checkout")
		return 2
	}
	switch args[0] {
	case "run":
		claim, rest := "", args[1:]
		for len(rest) > 0 && rest[0] != "--" {
			if rest[0] == "--claim" && len(rest) > 1 {
				claim, rest = rest[1], rest[2:]
				continue
			}
			fmt.Fprintln(os.Stderr, receiptUsage)
			return 2
		}
		if len(rest) < 2 {
			fmt.Fprintln(os.Stderr, receiptUsage)
			return 2
		}
		r, err := Run(root, claim, rest[1:], os.Stdout)
		if err != nil {
			fmt.Fprintln(os.Stderr, "receipt:", err)
			return 127
		}
		if err := Append(root, r); err != nil {
			fmt.Fprintln(os.Stderr, "receipt:", err)
			return 1
		}
		state := "fresh"
		if r.Dirty {
			state = "dirty tree: commit, then run it again for a fresh receipt"
		}
		fmt.Fprintf(os.Stderr, "receipt: %q exit %d at %s (%s)\n", r.Claim, r.Exit, short(r.Commit), state)
		return r.Exit
	case "list":
		md, all := false, false
		for _, a := range args[1:] {
			switch a {
			case "--md":
				md = true
			case "--all":
				all = true
			default:
				fmt.Fprintln(os.Stderr, receiptUsage)
				return 2
			}
		}
		rs, err := Load(root)
		if err != nil {
			fmt.Fprintln(os.Stderr, "receipt:", err)
			return 1
		}
		sha, _ := head(root)
		if !all {
			kept := rs[:0]
			for _, r := range rs {
				if r.Commit == sha {
					kept = append(kept, r)
				}
			}
			rs = kept
		}
		if md {
			fmt.Print(Markdown(rs, sha))
			return 0
		}
		for _, r := range rs {
			state := "fresh"
			if !r.Fresh(sha) {
				state = "stale"
			}
			fmt.Printf("%s\texit %d\t%s\t%s\t%s\n", short(r.Commit), r.Exit, state, r.Claim, strings.Join(r.Command, " "))
		}
		return 0
	case "clear":
		if err := os.Remove(receiptsPath(root)); err != nil && !os.IsNotExist(err) {
			fmt.Fprintln(os.Stderr, "receipt:", err)
			return 1
		}
		return 0
	}
	fmt.Fprintln(os.Stderr, receiptUsage)
	return 2
}
