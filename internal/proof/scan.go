package proof

import (
	"bytes"
	"fmt"
	"os"
	"path"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"

	"github.com/Zovaris/smithy/internal/ghx"
	"github.com/Zovaris/smithy/internal/gitx"
)

const scanUsage = `usage: smithy scan [--base <branch|ref>]
Checks the lines a change adds since the merge-base with the base (a branch name means
origin/<branch> when it exists; default origin's default branch), uncommitted edits
included, and the files it adds, for secrets and private keys.
Prints file:line, the rule and a masked match; exit 1 on any finding, 0 when clean.
A line that is a known false positive can carry "smithy:allow" to be skipped.`

type rule struct {
	name string
	re   *regexp.Regexp
}

var rules = []rule{
	{"private key", regexp.MustCompile(`-----BEGIN (?:RSA |EC |DSA |OPENSSH |PGP |ENCRYPTED )?PRIVATE KEY`)},
	{"aws access key", regexp.MustCompile(`\b(?:AKIA|ASIA)[0-9A-Z]{16}\b`)},
	{"github token", regexp.MustCompile(`\b(?:gh[pousr]_[A-Za-z0-9]{36,}|github_pat_[A-Za-z0-9_]{60,})\b`)},
	{"slack token", regexp.MustCompile(`\bxox[abprs]-[A-Za-z0-9-]{10,}`)},
	{"google api key", regexp.MustCompile(`\bAIza[0-9A-Za-z_-]{35}\b`)},
	{"stripe live key", regexp.MustCompile(`\b[rs]k_live_[0-9A-Za-z]{16,}\b`)},
	{"anthropic or openai key", regexp.MustCompile(`\bsk-(?:ant-|proj-)?[A-Za-z0-9_-]{32,}`)},
	{"jwt", regexp.MustCompile(`\beyJ[A-Za-z0-9_-]{10,}\.eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}`)},
	{"credentials in url", regexp.MustCompile(`[a-z][a-z0-9+.-]*://[^/\s:@'"]+:[^/\s@'"]{6,}@`)},
	{"hardcoded secret", regexp.MustCompile(`(?i)\b(?:password|passwd|secret|api[_-]?key|access[_-]?token|auth[_-]?token|client[_-]?secret)\b["']?\s*[:=]\s*["'][^"'\s$<{]{8,}["']`)},
}

var riskyFiles = regexp.MustCompile(`(?i)(^|/)(\.env(\.[a-z0-9_-]+)?|id_(rsa|dsa|ecdsa|ed25519)|[^/]+\.(pem|p12|pfx|key|keystore|jks)|credentials\.json|service[-_]account[^/]*\.json|\.npmrc|\.pypirc|\.netrc)$`)

var safeEnv = regexp.MustCompile(`(?i)\.env\.(example|sample|template|dist)$`)

// Finding is one suspected secret in a change.
type Finding struct {
	File  string
	Line  int
	Rule  string
	Match string
}

func (f Finding) String() string {
	if f.Line == 0 {
		return fmt.Sprintf("%s\t%s", f.File, f.Rule)
	}
	return fmt.Sprintf("%s:%d\t%s\t%s", f.File, f.Line, f.Rule, f.Match)
}

func mask(s string) string {
	if len(s) <= 8 {
		return strings.Repeat("*", len(s))
	}
	return s[:4] + strings.Repeat("*", len(s)-8) + s[len(s)-4:]
}

var hunkRe = regexp.MustCompile(`^@@ -\d+(?:,\d+)? \+(\d+)`)

// ScanDiff finds secrets in the added lines of a unified diff (git diff -U0 output).
func ScanDiff(diff string) []Finding {
	out, _ := scanDiff(diff)
	return out
}

// AllowedLines lists, as file:line, the added lines of a diff that carry smithy:allow.
func AllowedLines(diff string) []string {
	_, allowed := scanDiff(diff)
	return allowed
}

// AllowNote is the stderr line naming the lines skipped by smithy:allow.
func AllowNote(allowed []string) string {
	s := "s"
	if len(allowed) == 1 {
		s = ""
	}
	return fmt.Sprintf("scan: skipped %d line%s marked smithy:allow: %s", len(allowed), s, strings.Join(allowed, ", "))
}

func scanDiff(diff string) ([]Finding, []string) {
	var out []Finding
	var allowed []string
	file, line, header := "", 0, false
	for _, l := range strings.Split(diff, "\n") {
		switch {
		case strings.HasPrefix(l, "diff --git "):
			header = true
		case header && strings.HasPrefix(l, "+++ "):
			file = strings.TrimPrefix(strings.TrimPrefix(l, "+++ "), "b/")
		case header && !strings.HasPrefix(l, "@@"):
		case strings.HasPrefix(l, "@@"):
			header = false
			if m := hunkRe.FindStringSubmatch(l); m != nil {
				line, _ = strconv.Atoi(m[1])
			}
		case strings.HasPrefix(l, "+"):
			text := l[1:]
			if strings.Contains(text, "smithy:allow") {
				allowed = append(allowed, fmt.Sprintf("%s:%d", file, line))
			} else {
				for _, r := range rules {
					if m := r.re.FindString(text); m != "" {
						out = append(out, Finding{file, line, r.name, mask(m)})
					}
				}
			}
			line++
		}
	}
	return out, allowed
}

// scanUntracked checks the content of new files git doesn't track yet.
func scanUntracked(root string, names []string) ([]Finding, []string) {
	var out []Finding
	var allowed []string
	for _, n := range names {
		if n == "" {
			continue
		}
		b, err := os.ReadFile(filepath.Join(root, n))
		if err != nil || bytes.IndexByte(b, 0) >= 0 {
			continue
		}
		var d strings.Builder
		fmt.Fprintf(&d, "diff --git a/%s b/%s\n+++ b/%s\n@@ -0,0 +1 @@\n", n, n, n)
		for _, l := range strings.Split(string(b), "\n") {
			d.WriteString("+" + l + "\n")
		}
		fs, al := scanDiff(d.String())
		out, allowed = append(out, fs...), append(allowed, al...)
	}
	return out, allowed
}

// ScanFiles flags added files whose name alone means a secret or key.
func ScanFiles(names []string) []Finding {
	var out []Finding
	for _, n := range names {
		if n != "" && riskyFiles.MatchString(n) && !safeEnv.MatchString(path.Base(n)) {
			out = append(out, Finding{File: n, Rule: "secret-bearing file"})
		}
	}
	return out
}

// ScanMain runs `smithy scan`.
func ScanMain(args []string) int {
	base := ""
	for i := 0; i < len(args); i++ {
		switch {
		case args[i] == "--base" && i+1 < len(args):
			base = args[i+1]
			i++
		default:
			fmt.Fprintln(os.Stderr, scanUsage)
			if args[i] == "-h" || args[i] == "--help" {
				return 0
			}
			return 2
		}
	}
	cwd, _ := os.Getwd()
	root := ghx.RepoRoot(cwd)
	if root == "" {
		fmt.Fprintln(os.Stderr, "scan: not inside a git checkout")
		return 2
	}
	if strings.HasPrefix(base, "-") {
		fmt.Fprintln(os.Stderr, "scan: --base must be a branch or ref, not an option")
		return 2
	}
	base, label := gitx.ResolveBase(root, base)
	diff, err := ghx.Run("git", "-C", root, "-c", "core.quotepath=false", "diff", "--no-color", "--no-ext-diff", "-U0", base, "--")
	if err != nil {
		fmt.Fprintln(os.Stderr, "scan:", err)
		return 2
	}
	added, _ := ghx.Run("git", "-C", root, "diff", "-z", "-M", "--name-only", "--diff-filter=AR", base, "--")
	untracked, _ := ghx.Run("git", "-C", root, "ls-files", "-z", "--others", "--exclude-standard")
	news := strings.Split(strings.Trim(untracked, "\x00"), "\x00")
	dfs, allowed := scanDiff(diff)
	ufs, uallowed := scanUntracked(root, news)
	fs := append(ScanFiles(append(strings.Split(added, "\x00"), news...)), dfs...)
	fs = append(fs, ufs...)
	for _, f := range fs {
		fmt.Println(f)
	}
	if allowed = append(allowed, uallowed...); len(allowed) > 0 {
		fmt.Fprintln(os.Stderr, AllowNote(allowed))
	}
	if len(fs) > 0 {
		fmt.Fprintf(os.Stderr, "scan: %d possible secret(s); remove them, or mark a false positive with smithy:allow\n", len(fs))
		return 1
	}
	fmt.Fprintf(os.Stderr, "scan: clean against %s\n", label)
	return 0
}
