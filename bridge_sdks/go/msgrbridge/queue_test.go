package msgrbridge

import "testing"

func TestTopic(t *testing.T) {
	if got := Topic("telegram", "send"); got != "bridge/telegram/send" {
		t.Fatalf("unexpected topic: %s", got)
	}
}

func TestTopicForInstance(t *testing.T) {
	if got := TopicForInstance("matrix", "matrix-1", "send"); got != "bridge/matrix/matrix-1/send" {
		t.Fatalf("unexpected topic: %s", got)
	}
	if got := TopicForInstance("matrix", "", "send"); got != "bridge/matrix/send" {
		t.Fatalf("unexpected topic for empty instance: %s", got)
	}
}
