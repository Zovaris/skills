package gitx

import (
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strings"

	"github.com/Zovaris/smithy/internal/ghx"
)

const prUsage = `Pull requests that follow the repo's PR template.
  smithy pr template                        print the template path(s); exit 1 when the repo has none
  smithy pr create --base <b> --title "<t>" --body-file <f> [--draft]
                                            open the PR for the current branch, or print the open one
With a template, the body must keep every heading of the template (fill them, write "N/A" when
one doesn't apply). The title follows the commit style (smithy commit check).`

var headingRe = regexp.MustCompile(`^#{1,4} `)

// Templates lists the PR template files of the repo at top, first the single-file ones.
func Templates(top string) []string {
	var out []string
	var seen []os.FileInfo
	for _, f := range []string{".github/pull_request_template.md", ".github/PULL_REQUEST_TEMPLATE.md", "docs/pull_request_template.md",
		"docs/PULL_REQUEST_TEMPLATE.md", "pull_request_template.md", "PULL_REQUEST_TEMPLATE.md"} {
		p := filepath.Join(top, f)
		fi, err := os.Stat(p)
		if err != nil || !fi.Mode().IsRegular() {
			continue
		}
		dup := false
		for _, s := range seen {
			if os.SameFile(s, fi) {
				dup = true
			}
		}
		if dup {
			continue
		}
		seen = append(seen, fi)
		out = append(out, p)
	}
	m, _ := filepath.Glob(filepath.Join(top, ".github", "PULL_REQUEST_TEMPLATE", "*.md"))
	sort.Strings(m)
	return append(out, m...)
}

// MissingHeadings returns the template's headings (#..#### lines) that body lacks as whole lines.
func MissingHeadings(template, body string) []string {
	have := map[string]bool{}
	for _, l := range strings.Split(body, "\n") {
		have[l] = true
	}
	var miss []string
	for _, h := range strings.Split(template, "\n") {
		if headingRe.MatchString(h) && !have[h] {
			miss = append(miss, h)
		}
	}
	return miss
}

// PRMain runs `smithy pr` and returns the exit code.
func PRMain(args []string) int {
	const p = "smithy pr"
	wd, _ := os.Getwd()
	top := ghx.RepoRoot(wd)
	if top == "" {
		return die(p, "not a git repo")
	}
	for _, a := range args {
		if a == "-h" || a == "--help" {
			fmt.Println(prUsage)
			return 0
		}
	}
	if len(args) == 0 || (args[0] != "template" && args[0] != "create") {
		fmt.Println(prUsage)
		return 2
	}
	if args[0] == "template" {
		t := Templates(top)
		if len(t) == 0 {
			fmt.Fprintln(os.Stderr, "smithy pr template: no PR template in this repo; write what and why, tests, commands run")
			return 1
		}
		fmt.Println(strings.Join(t, "\n"))
		return 0
	}
	const use = `usage: smithy pr create --base <b> --title "<t>" --body-file <f> [--draft]`
	var base, title, body string
	draft := false
	rest := args[1:]
	for len(rest) > 0 {
		switch rest[0] {
		case "--base", "--title", "--body-file":
			if len(rest) < 2 {
				die(p, use)
				return 2
			}
			switch rest[0] {
			case "--base":
				base = rest[1]
			case "--title":
				title = rest[1]
			default:
				body = rest[1]
			}
			rest = rest[2:]
		case "--draft":
			draft = true
			rest = rest[1:]
		default:
			die(p, "unknown option %s", rest[0])
			return 2
		}
	}
	if fi, err := os.Stat(body); base == "" || title == "" || err != nil || !fi.Mode().IsRegular() {
		die(p, use)
		return 2
	}
	branch := git("branch", "--show-current")
	var open []struct {
		URL string `json:"url"`
	}
	if ghx.GH(&open, "pr", "list", "--head", branch, "--state", "open", "--json", "url") == nil && len(open) > 0 && open[0].URL != "" {
		fmt.Println(open[0].URL)
		return 0
	}
	if err := Check(title, detect()); err != nil {
		return die(p, "title doesn't follow the commit style: smithy commit: %s", err)
	}
	if t := Templates(top); len(t) > 0 {
		tb, _ := os.ReadFile(t[0])
		bb, _ := os.ReadFile(body)
		if miss := MissingHeadings(string(tb), string(bb)); len(miss) > 0 {
			rel, _ := filepath.Rel(top, t[0])
			return die(p, "body drops template headings from %s: %s", rel, strings.Join(miss, "|"))
		}
	}
	if c := attached("git", "push", "-q", "-u", "origin", branch); c != 0 {
		return c
	}
	ca := []string{"pr", "create", "--base", base, "--head", branch, "--title", title, "--body-file", body}
	if draft {
		ca = append(ca, "--draft")
	}
	return attached("gh", ca...)
}
