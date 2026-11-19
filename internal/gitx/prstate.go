package gitx

import (
	"bytes"
	"encoding/json"
	"fmt"
	"os"
	"regexp"
	"strconv"
	"strings"

	"github.com/Zovaris/smithy/internal/ghx"
)

const prStateUsage = "usage: smithy pr-state <pr-url|number|branch>"

var (
	stateFailRe    = regexp.MustCompile(`FAIL|ERROR|CANCEL|TIMED_OUT|ACTION_REQUIRED|STARTUP_FAILURE`)
	statePendingRe = regexp.MustCompile(`PENDING|QUEUED|IN_PROGRESS|EXPECTED|WAITING|REQUESTED`)
)

// PRState is the compact state of one PR that tend decides from.
type PRState struct {
	URL        any    `json:"url"`
	State      any    `json:"state"`
	Checks     string `json:"checks"`
	Mergeable  any    `json:"mergeable"`
	Review     any    `json:"review"`
	Unresolved int    `json:"unresolved"`
	Behind     any    `json:"behind"`
	Head       any    `json:"head"`
	Base       any    `json:"base"`
}

type stateView struct {
	URL               any      `json:"url"`
	Number            int      `json:"number"`
	State             any      `json:"state"`
	Mergeable         any      `json:"mergeable"`
	ReviewDecision    any      `json:"reviewDecision"`
	StatusCheckRollup []Rollup `json:"statusCheckRollup"`
	HeadRefName       any      `json:"headRefName"`
	BaseRefName       any      `json:"baseRefName"`
	HeadOwner         *struct {
		Login string `json:"login"`
	} `json:"headRepositoryOwner"`
}

type threads struct {
	Data struct {
		Repository struct {
			PullRequest struct {
				ReviewThreads struct {
					Nodes []struct {
						IsResolved bool `json:"isResolved"`
					} `json:"nodes"`
				} `json:"reviewThreads"`
			} `json:"pullRequest"`
		} `json:"repository"`
	} `json:"data"`
}

type compare struct {
	BehindBy any `json:"behind_by"`
}

func orElse(v, fallback any) any {
	if v == nil || v == false {
		return fallback
	}
	return v
}

func decode(b []byte, v any) error {
	d := json.NewDecoder(bytes.NewReader(b))
	d.UseNumber()
	return d.Decode(v)
}

// Summarize builds the PR state from the raw JSON of `gh pr view`, the review-threads GraphQL
// query and the compare API.
func Summarize(view, thr, cmp []byte) (PRState, error) {
	var v stateView
	var t threads
	var c compare
	if err := decode(view, &v); err != nil {
		return PRState{}, fmt.Errorf("view: %w", err)
	}
	if err := decode(thr, &t); err != nil {
		return PRState{}, fmt.Errorf("threads: %w", err)
	}
	if err := decode(cmp, &c); err != nil {
		return PRState{}, fmt.Errorf("compare: %w", err)
	}
	up := make([]Rollup, len(v.StatusCheckRollup))
	for i, r := range v.StatusCheckRollup {
		up[i] = Rollup{Conclusion: strings.ToUpper(r.outcome())}
	}
	unresolved := 0
	for _, n := range t.Data.Repository.PullRequest.ReviewThreads.Nodes {
		if !n.IsResolved {
			unresolved++
		}
	}
	review := orElse(v.ReviewDecision, "")
	if review == "" {
		review = "none"
	}
	return PRState{
		URL:        v.URL,
		State:      v.State,
		Checks:     Checks(up, stateFailRe, statePendingRe),
		Mergeable:  orElse(v.Mergeable, "UNKNOWN"),
		Review:     review,
		Unresolved: unresolved,
		Behind:     orElse(c.BehindBy, 0),
		Head:       v.HeadRefName,
		Base:       v.BaseRefName,
	}, nil
}

func printState(s PRState) int {
	var buf bytes.Buffer
	enc := json.NewEncoder(&buf)
	enc.SetEscapeHTML(false)
	if err := enc.Encode(s); err != nil {
		fmt.Fprintln(os.Stderr, "smithy pr-state:", err)
		return 1
	}
	os.Stdout.Write(buf.Bytes())
	return 0
}

// PRStateMain runs `smithy pr-state`.
func PRStateMain(args []string) int {
	if len(args) > 0 && args[0] == "--from" {
		if len(args) != 4 {
			fmt.Fprintln(os.Stderr, "usage: smithy pr-state --from <view.json> <threads.json> <compare.json>")
			return 2
		}
		var raw [3][]byte
		for i, f := range args[1:] {
			b, err := os.ReadFile(f)
			if err != nil {
				fmt.Fprintln(os.Stderr, "smithy pr-state:", err)
				return 2
			}
			raw[i] = b
		}
		s, err := Summarize(raw[0], raw[1], raw[2])
		if err != nil {
			fmt.Fprintln(os.Stderr, "smithy pr-state:", err)
			return 2
		}
		return printState(s)
	}
	if len(args) != 1 {
		fmt.Fprintln(os.Stderr, prStateUsage)
		return 2
	}
	if _, err := ghx.Run("gh", "auth", "status"); err != nil {
		fmt.Fprintln(os.Stderr, "smithy pr-state: gh is missing or signed out: install the GitHub CLI and run `gh auth login`")
		return 3
	}
	view, err := ghx.Run("gh", "pr", "view", args[0], "--json", "url,number,state,mergeable,reviewDecision,statusCheckRollup,headRefName,baseRefName,headRepositoryOwner,headRepository")
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		return 1
	}
	var repo struct {
		Name  string `json:"name"`
		Owner struct {
			Login string `json:"login"`
		} `json:"owner"`
	}
	if err := ghx.GH(&repo, "repo", "view", "--json", "owner,name"); err != nil {
		fmt.Fprintln(os.Stderr, err)
		return 1
	}
	var v stateView
	if err := decode([]byte(view), &v); err != nil {
		fmt.Fprintln(os.Stderr, "smithy pr-state:", err)
		return 1
	}
	thr, err := ghx.Run("gh", "api", "graphql", "-F", "owner="+repo.Owner.Login, "-F", "name="+repo.Name, "-F", "num="+strconv.Itoa(v.Number), "-f", `query=
  query($owner:String!,$name:String!,$num:Int!){repository(owner:$owner,name:$name){pullRequest(number:$num){
    reviewThreads(first:100){nodes{isResolved}}}}}`)
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		return 1
	}
	head := jqText(v.HeadRefName)
	if v.HeadOwner != nil && v.HeadOwner.Login != "" {
		head = v.HeadOwner.Login + ":" + head
	}
	cmp, err := ghx.Run("gh", "api", "repos/"+repo.Owner.Login+"/"+repo.Name+"/compare/"+jqText(v.BaseRefName)+"..."+head)
	if err != nil {
		cmp = `{"behind_by":0}`
	}
	s, err := Summarize([]byte(view), []byte(thr), []byte(cmp))
	if err != nil {
		fmt.Fprintln(os.Stderr, "smithy pr-state:", err)
		return 1
	}
	return printState(s)
}
