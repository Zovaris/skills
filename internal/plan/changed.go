package plan

import (
	"bytes"
	"fmt"
	"os"
	"os/exec"
	"regexp"
	"sort"
	"strings"
)

const changedUsage = `smelt: source files changed against a base, without tests, docs or generated files.
  smithy changed [base]   (default: merge-base with origin's default branch)
One path per line; ` + "`--csv`" + ` as last arg joins them with commas (for Stryker --mutate).`

var (
	sourceFile = regexp.MustCompile(`\.(ts|tsx|js|jsx|mjs|cjs|py|rs|go|rb|java|kt|swift)$`)
	notSource  = regexp.MustCompile(`(^|/)(tests?|__tests__|spec|e2e|fixtures|__snapshots__)/|\.(test|spec|adversary|property)\.|(^|/)test_[^/]*\.py$|_test\.(go|py)$|\.d\.ts$|(^|/)(dist|build|generated)/`)
)

// Source keeps the source files among paths, sorted and unique, dropping tests, docs,
// fixtures, type declarations and generated output.
func Source(paths []string) []string {
	seen := map[string]bool{}
	var keep []string
	for _, p := range paths {
		if p == "" || seen[p] {
			continue
		}
		seen[p] = true
		if sourceFile.MatchString(p) && !notSource.MatchString(p) {
			keep = append(keep, p)
		}
	}
	sort.Strings(keep)
	return keep
}

func gitLines(args ...string) ([]string, error) {
	cmd := exec.Command("git", args...)
	var stderr bytes.Buffer
	cmd.Stderr = &stderr
	out, err := cmd.Output()
	if err != nil {
		os.Stderr.Write(stderr.Bytes())
		return nil, err
	}
	return strings.Split(strings.TrimRight(string(out), "\n"), "\n"), nil
}

// DefaultBase is the merge-base of HEAD with origin's default branch (origin/main when unset).
func DefaultBase() (string, error) {
	d := "origin/main"
	if b, err := exec.Command("git", "symbolic-ref", "-q", "--short", "refs/remotes/origin/HEAD").Output(); err == nil {
		d = strings.TrimSpace(string(b))
	}
	l, err := gitLines("merge-base", "HEAD", d)
	if err != nil {
		return "", err
	}
	return l[0], nil
}

// Changed lists the source files changed in base...HEAD plus the uncommitted ones.
func Changed(base string) []string {
	committed, _ := gitLines("diff", "--name-only", "--diff-filter=ACMR", base+"...HEAD")
	working, _ := gitLines("diff", "--name-only", "--diff-filter=ACMR")
	return Source(append(committed, working...))
}

// ChangedMain runs `smithy changed [base] [--csv]` and returns the exit code.
func ChangedMain(args []string) int {
	if len(args) > 0 && (args[0] == "-h" || args[0] == "--help") {
		fmt.Fprintln(os.Stderr, changedUsage)
		return 0
	}
	sep := "\n"
	if len(args) > 0 && args[len(args)-1] == "--csv" {
		sep, args = ",", args[:len(args)-1]
	}
	base := ""
	if len(args) > 0 {
		base = args[0]
	}
	if base == "" {
		b, err := DefaultBase()
		if err != nil {
			if e, ok := err.(*exec.ExitError); ok {
				return e.ExitCode()
			}
			return 1
		}
		base = b
	}
	fmt.Println(strings.Join(Changed(base), sep))
	return 0
}
