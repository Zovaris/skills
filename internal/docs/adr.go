package docs

import (
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
	"time"
)

const adrUsage = `smithy adr: creates the next numbered ADR (MADR-compatible headings) and prints its path.
  smithy adr "<title>" [adr-dir]      (default docs/adr)
Numbers are never reused; 0000 is reserved for "record architecture decisions" (docs init).`

var (
	adrNumber  = regexp.MustCompile(`^[0-9]{4}`)
	slugNonAln = regexp.MustCompile(`[^a-z0-9]+`)
)

const adrTemplate = `# %s · %s

- Status: proposed
- Date: %s

## Context and Problem Statement

<What forced a decision, in one or two paragraphs.>

## Considered Options

- <option> — <why not>

## Decision Outcome

Chosen option: "<option>", because <reason>.

## Consequences

- Good: <what gets easier>
- Bad: <what gets harder>
`

// ADRSlug turns a title into the file-name slug: ASCII lowercase, runs of other characters as
// one hyphen, trimmed, at most 60 characters.
func ADRSlug(title string) string {
	b := []byte(title)
	for i, c := range b {
		if c >= 'A' && c <= 'Z' {
			b[i] = c + 'a' - 'A'
		}
	}
	s := slugNonAln.ReplaceAllString(string(b), "-")
	s = strings.TrimPrefix(s, "-")
	s = strings.TrimSuffix(s, "-")
	if len(s) > 60 {
		s = s[:60]
	}
	return s
}

// NextADRNumber is the number after the highest four-digit prefix among the names in dir.
func NextADRNumber(dir string) string {
	last := 0
	entries, _ := os.ReadDir(dir)
	for _, e := range entries {
		if strings.HasPrefix(e.Name(), ".") {
			continue
		}
		if m := adrNumber.FindString(e.Name()); m != "" {
			if n, _ := strconv.Atoi(m); n > last {
				last = n
			}
		}
	}
	return fmt.Sprintf("%04d", last+1)
}

// ADR runs `smithy adr "<title>" [adr-dir]`.
func ADR(args []string) int {
	if len(args) < 1 || args[0] == "" || wantsHelp(args) {
		fmt.Fprintln(os.Stderr, adrUsage)
		return 2
	}
	title := args[0]
	dir := "docs/adr"
	if len(args) > 1 && args[1] != "" {
		if err := os.MkdirAll(args[1], 0o755); err != nil {
			fmt.Fprintln(os.Stderr, "smithy adr:", err)
			return 1
		}
		abs, err := filepath.Abs(args[1])
		if err != nil {
			fmt.Fprintln(os.Stderr, "smithy adr:", err)
			return 1
		}
		dir = abs
	}
	if root := strings.TrimSpace(git("rev-parse", "--show-toplevel")); root != "" {
		if err := os.Chdir(root); err != nil {
			fmt.Fprintln(os.Stderr, "smithy adr:", err)
			return 1
		}
	}
	if err := os.MkdirAll(dir, 0o755); err != nil {
		fmt.Fprintln(os.Stderr, "smithy adr:", err)
		return 1
	}
	n := NextADRNumber(dir)
	slug := ADRSlug(title)
	if slug == "" {
		fmt.Fprintln(os.Stderr, "smithy adr: title has no letters or digits")
		return 2
	}
	f := dir + "/" + n + "-" + slug + ".md"
	body := fmt.Sprintf(adrTemplate, n, title, time.Now().Format("2006-01-02"))
	if err := os.WriteFile(f, []byte(body), 0o644); err != nil {
		fmt.Fprintln(os.Stderr, "smithy adr:", err)
		return 1
	}
	fmt.Println(f)
	return 0
}
