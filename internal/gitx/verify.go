package gitx

import (
	"encoding/json"
	"fmt"
	"os"
	"regexp"
	"strconv"

	"github.com/Zovaris/skills/internal/ghx"
)

const verifyUsage = "usage: smithy verify <repo> <branch> [pr]"

var (
	failRe    = regexp.MustCompile(`(?i)FAIL|ERROR|CANCEL|TIMED_OUT|ACTION_REQUIRED`)
	pendingRe = regexp.MustCompile(`(?i)PENDING|QUEUED|IN_PROGRESS|EXPECTED|WAITING`)
)

// Rollup is one entry of a PR's statusCheckRollup.
type Rollup struct {
	Conclusion string `json:"conclusion"`
	State      string `json:"state"`
}

func (r Rollup) outcome() string {
	switch {
	case r.Conclusion != "":
		return r.Conclusion
	case r.State != "":
		return r.State
	}
	return "PENDING"
}

// Checks sums a statusCheckRollup into pass, fail, pending or none, using these patterns.
func Checks(rollup []Rollup, fail, pending *regexp.Regexp) string {
	if len(rollup) == 0 {
		return "none"
	}
	anyOf := func(re *regexp.Regexp) bool {
		for _, r := range rollup {
			if re.MatchString(r.outcome()) {
				return true
			}
		}
		return false
	}
	switch {
	case anyOf(fail):
		return "fail"
	case anyOf(pending):
		return "pending"
	}
	return "pass"
}

type prView struct {
	URL               any      `json:"url"`
	State             any      `json:"state"`
	HeadRefOid        any      `json:"headRefOid"`
	Mergeable         any      `json:"mergeable"`
	IsDraft           any      `json:"isDraft"`
	StatusCheckRollup []Rollup `json:"statusCheckRollup"`
}

func jqText(v any) string {
	switch t := v.(type) {
	case nil:
		return "null"
	case string:
		return t
	case bool:
		return strconv.FormatBool(t)
	}
	b, _ := json.Marshal(v)
	return string(b)
}

// Verdict is the verify verdict for a PR given the worker's local head; ancestor reports whether
// local is an ancestor of the PR head.
func Verdict(state, checks, mergeable string, draft bool, local, head string, ancestor func() bool) string {
	switch state {
	case "MERGED":
		return "merged"
	case "CLOSED":
		return "closed"
	}
	if local != "" && local != head && !ancestor() {
		return "unpushed"
	}
	if draft {
		return "pending"
	}
	switch checks {
	case "fail":
		return "red"
	case "pending":
		return "pending"
	}
	if mergeable == "CONFLICTING" {
		return "red"
	}
	return "green"
}

// VerifyMain runs `smithy verify`: one line of proof for a worker's PR claim; exit 0 for green or merged.
func VerifyMain(args []string) int {
	if len(args) < 2 {
		fmt.Fprintln(os.Stderr, verifyUsage)
		return 2
	}
	branch, pr := args[1], ""
	if len(args) > 2 {
		pr = args[2]
	}
	if err := os.Chdir(args[0]); err != nil {
		fmt.Fprintln(os.Stderr, "smithy verify:", err)
		return 1
	}
	if pr == "" {
		var list []struct {
			Number int `json:"number"`
		}
		if ghx.GH(&list, "pr", "list", "--head", branch, "--state", "all", "--json", "number") == nil && len(list) > 0 {
			pr = strconv.Itoa(list[0].Number)
		}
	}
	if pr == "" {
		fmt.Printf("no-pr branch=%s\n", branch)
		return 1
	}
	var v prView
	if err := ghx.GH(&v, "pr", "view", pr, "--json", "url,state,headRefOid,mergeable,isDraft,statusCheckRollup"); err != nil {
		fmt.Fprintln(os.Stderr, err)
		return 1
	}
	state, head, mergeable, draft := jqText(v.State), jqText(v.HeadRefOid), jqText(v.Mergeable), jqText(v.IsDraft)
	checks := Checks(v.StatusCheckRollup, failRe, pendingRe)
	local := git("rev-parse", "--verify", "-q", "refs/heads/"+branch)
	verdict := Verdict(state, checks, mergeable, draft == "true", local, head, func() bool {
		return quiet("git", "merge-base", "--is-ancestor", local, head) == nil
	})
	short := head
	if len(short) > 7 {
		short = short[:7]
	}
	fmt.Printf("%s pr=%s state=%s head=%s checks=%s mergeable=%s draft=%s\n", verdict, jqText(v.URL), state, short, checks, mergeable, draft)
	if verdict == "green" || verdict == "merged" {
		return 0
	}
	return 1
}
