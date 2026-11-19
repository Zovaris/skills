package warden

import (
	"strings"
	"testing"
)

func TestWaitTurnBadStackSaysWhy(t *testing.T) {
	newBatch(t, `{"stack":"ask","items":[{"id":"a"}]}`)
	_, e, c := capture(t, func() int { return WaitTurn([]string{"b1", "a", "0"}) })
	if c != 2 || !strings.Contains(e, "batch.json unreadable: stack must be true or false") {
		t.Fatalf("%d %q", c, e)
	}
}
