package msgrbridge

import "testing"

func TestTopic(t *testing.T) {
	if got := Topic("telegram", "send"); got != "bridge/telegram/send" {
		t.Fatalf("unexpected topic: %s", got)
	}
}
