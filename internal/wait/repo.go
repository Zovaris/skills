package wait

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"

	"github.com/Zovaris/smithy/internal/ghx"
)

func tendDir() string {
	if d := os.Getenv("TEND_HOME"); d != "" {
		return d
	}
	return filepath.Join(ghx.Home(), "tend")
}

// seenSet is a persisted set of keys, so a watcher reports each event once across restarts.
type seenSet struct {
	file string
	keys map[string]bool
	init bool
}

func newSeen(name string) *seenSet {
	repo, _ := ghx.RepoName()
	s := &seenSet{file: filepath.Join(tendDir(), strings.ReplaceAll(repo, "/", "-")+"-"+name+".json"), keys: map[string]bool{}}
	if b, err := os.ReadFile(s.file); err == nil {
		var ks []string
		if json.Unmarshal(b, &ks) == nil {
			s.init = true
			for _, k := range ks {
				s.keys[k] = true
			}
		}
	}
	return s
}

// fresh returns the keys not seen before and saves all of them; the first run only records.
func (s *seenSet) fresh(now []string) []string {
	var out []string
	for _, k := range now {
		if !s.keys[k] {
			out = append(out, k)
		}
		s.keys[k] = true
	}
	first := !s.init
	s.init = true
	if len(out) > 0 || first {
		ks := make([]string, 0, len(s.keys))
		for k := range s.keys {
			ks = append(ks, k)
		}
		sort.Strings(ks)
		_ = os.MkdirAll(filepath.Dir(s.file), 0o755)
		b, _ := json.Marshal(ks)
		_ = os.WriteFile(s.file, b, 0o644)
	}
	if first {
		return nil
	}
	return out
}

func defaultBranch() string {
	if r, err := ghx.Run("git", "symbolic-ref", "--quiet", "--short", "refs/remotes/origin/HEAD"); err == nil && r != "" {
		return strings.TrimPrefix(r, "origin/")
	}
	return "main"
}

// actionsWatcher reports workflow runs on a branch that finished red (push, schedule, manual).
type actionsWatcher struct {
	branch string
	seen   *seenSet
}

func newActions(branch string) *actionsWatcher {
	if branch == "" {
		branch = defaultBranch()
	}
	return &actionsWatcher{branch, newSeen("actions-" + strings.ReplaceAll(branch, "/", "-"))}
}

func (w *actionsWatcher) poll() ([]string, error) {
	var runs []struct {
		DatabaseID                     int64
		Status, Conclusion, Name, URL string
	}
	if err := ghx.RunList(w.branch, &runs); err != nil {
		return nil, err
	}
	byKey := map[string]string{}
	var keys []string
	for _, r := range runs {
		if r.Status != "completed" || ok(r.Conclusion) {
			continue
		}
		k := fmt.Sprint(r.DatabaseID)
		byKey[k] = fmt.Sprintf("actions %s %s %s %s", k, r.Conclusion, dash(r.Name), r.URL)
		keys = append(keys, k)
	}
	var out []string
	for _, k := range w.seen.fresh(keys) {
		out = append(out, byKey[k])
	}
	return out, nil
}

// baseWatcher reports a branch moving on origin.
type baseWatcher struct {
	branch string
	seen   *seenSet
}

func newBase(branch string) *baseWatcher {
	if branch == "" {
		branch = defaultBranch()
	}
	return &baseWatcher{branch, newSeen("base-" + strings.ReplaceAll(branch, "/", "-"))}
}

func (w *baseWatcher) poll() ([]string, error) {
	out, err := ghx.Run("git", "ls-remote", "origin", "refs/heads/"+w.branch)
	if err != nil {
		return nil, err
	}
	f := strings.Fields(out)
	if len(f) == 0 {
		return nil, fmt.Errorf("no branch %s on origin", w.branch)
	}
	if len(w.seen.fresh([]string{f[0]})) == 0 {
		return nil, nil
	}
	return []string{fmt.Sprintf("base %s moved %s", w.branch, f[0][:7])}, nil
}

// alertsWatcher reports new open Dependabot alerts; without read access it says so once and
// then stays quiet.
type alertsWatcher struct {
	seen *seenSet
	off  bool
}

func (w *alertsWatcher) poll() ([]string, error) {
	if w.off {
		return nil, nil
	}
	var as []struct {
		Number                 int
		Severity, Package, URL string
	}
	if err := ghx.Alerts(&as); err != nil {
		w.off = true
		fmt.Fprintln(os.Stderr, "smithy wait: alerts not readable here, skipping them:", err)
		return nil, nil
	}
	byKey := map[string]string{}
	var keys []string
	for _, a := range as {
		k := fmt.Sprint(a.Number)
		byKey[k] = fmt.Sprintf("alert %s %s %s %s", k, a.Severity, a.Package, a.URL)
		keys = append(keys, k)
	}
	var out []string
	for _, k := range w.seen.fresh(keys) {
		out = append(out, byKey[k])
	}
	return out, nil
}
