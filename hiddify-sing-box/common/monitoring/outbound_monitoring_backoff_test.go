package monitoring

import (
	"errors"
	"testing"
	"time"
)

// A failing IP info lookup used to leave history.IpInfo nil, which made tester()
// retry the whole provider walk for that outbound on every cycle. These cover the
// backoff that replaced that behaviour.
func TestIpInfoDueBacksOffAfterFailures(t *testing.T) {
	m := &OutboundMonitoring{}
	out := &outboundState{}

	if !m.ipInfoDue(out) {
		t.Fatal("a never-tried outbound should be due")
	}

	m.noteIpInfoResult(out, errors.New("429"))
	if m.ipInfoDue(out) {
		t.Fatal("should not retry immediately after a failure")
	}

	// One failure => one base interval.
	out.ipInfoFailedAt = time.Now().Add(-ipInfoBaseBackoff - time.Second)
	if !m.ipInfoDue(out) {
		t.Fatalf("should be due again after %s", ipInfoBaseBackoff)
	}

	// Each further failure doubles the wait, so the same age is no longer enough.
	m.noteIpInfoResult(out, errors.New("429"))
	out.ipInfoFailedAt = time.Now().Add(-ipInfoBaseBackoff - time.Second)
	if m.ipInfoDue(out) {
		t.Fatal("second failure should require a longer wait than the first")
	}
}

func TestIpInfoBackoffIsCapped(t *testing.T) {
	m := &OutboundMonitoring{}
	out := &outboundState{ipInfoFailures: 100}

	out.ipInfoFailedAt = time.Now().Add(-ipInfoMaxBackoff + time.Minute)
	if m.ipInfoDue(out) {
		t.Fatal("should still be waiting just inside the cap")
	}
	out.ipInfoFailedAt = time.Now().Add(-ipInfoMaxBackoff - time.Minute)
	if !m.ipInfoDue(out) {
		t.Fatalf("backoff must not grow past %s; a recovered provider has to be picked up again", ipInfoMaxBackoff)
	}
}

func TestIpInfoSuccessClearsBackoff(t *testing.T) {
	m := &OutboundMonitoring{}
	out := &outboundState{}

	m.noteIpInfoResult(out, errors.New("boom"))
	m.noteIpInfoResult(out, errors.New("boom"))
	m.noteIpInfoResult(out, nil)

	if out.ipInfoFailures != 0 || !out.ipInfoFailedAt.IsZero() {
		t.Fatalf("success must reset the counter, got failures=%d at=%v", out.ipInfoFailures, out.ipInfoFailedAt)
	}
	if !m.ipInfoDue(out) {
		t.Fatal("an outbound that just succeeded should be due")
	}
}
