package wait

import "testing"

func TestSummarize(t *testing.T) {
	if s := summarize(nil); s.state != "none" {
		t.Errorf("no checks: %v", s)
	}
	if s := summarize([]check{{Name: "unit", Status: "IN_PROGRESS"}}); s.state != "pending" {
		t.Errorf("in progress: %v", s)
	}
	s := summarize([]check{{Name: "unit tests", Status: "COMPLETED", Conclusion: "FAILURE"}, {Name: "lint", Status: "COMPLETED", Conclusion: "SUCCESS"}})
	if s.state != "red" || len(s.failed) != 1 || s.failed[0] != "unit-tests" {
		t.Errorf("red: %v", s)
	}
	if s := summarize([]check{{Context: "ci/legacy", State: "SUCCESS"}}); s.state != "green" {
		t.Errorf("status context: %v", s)
	}
}
