package config

import (
	"fmt"
	"strings"
	"sync"
	"testing"
)

func TestReadPathsReportBrokenFile(t *testing.T) {
	for _, content := range []string{`{not json`, `null`, `[1]`, `"x"`} {
		for _, args := range [][]string{{"model", "cheap"}, {"get", "warden.max"}, {"list"}} {
			e := setup(t)
			write(t, e.user, content)
			_, se, code := capture(t, func() int { return Main(args) })
			if code != 1 || !strings.Contains(se, e.user) || !strings.Contains(se, "not a JSON object") {
				t.Errorf("%s with %q: code %d err %q", args, content, code, se)
			}
		}
	}
}

func TestSetModelNullFile(t *testing.T) {
	e := setup(t)
	write(t, e.user, "null")
	_, se, code := capture(t, func() int { return Main([]string{"set-model", "cheap", "mini"}) })
	if code != 1 || !strings.Contains(se, "not a JSON object") {
		t.Fatalf("code %d err %q", code, se)
	}
}

func TestRejectBadKeysAndNames(t *testing.T) {
	for _, args := range [][]string{
		{"set", "", "v"},
		{"set", "a..b", "v"},
		{"set", ".a", "v"},
		{"set", "a.", "v"},
		{"unset", "a..b"},
		{"get", ""},
		{"get", "a..b"},
		{"set-model", "cheap", ""},
		{"set-model", "cheap", "  "},
		{"set-model", "cheap", "m", "a/b"},
		{"set-model", "cheap", "m", "a.b"},
		{"set-model", "cheap", "m", ""},
	} {
		setup(t)
		if _, se, code := capture(t, func() int { return Main(args) }); code != 2 || se == "" {
			t.Errorf("%q: code %d err %q", args, code, se)
		}
	}
}

func TestConcurrentSetKeepsEveryWrite(t *testing.T) {
	e := setup(t)
	var wg sync.WaitGroup
	for i := 0; i < 20; i++ {
		wg.Add(1)
		go func(i int) {
			defer wg.Done()
			if err := Set(e.user, fmt.Sprintf("k.n%d", i), "1"); err != nil {
				t.Error(err)
			}
		}(i)
	}
	wg.Wait()
	for i := 0; i < 20; i++ {
		if _, ok := readKey(e.user, fmt.Sprintf("k.n%d", i)); !ok {
			t.Errorf("k.n%d lost", i)
		}
	}
}
