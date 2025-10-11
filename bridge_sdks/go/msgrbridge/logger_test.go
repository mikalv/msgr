package msgrbridge

import (
	"context"
	"errors"
	"testing"
	"time"
)

type captureQueue struct {
	topic string
	body  []byte
	err   error
}

func (c *captureQueue) Subscribe(_ context.Context, _ string, _ QueueMessageHandler) error {
	return errors.New("not implemented")
}

func (c *captureQueue) Publish(_ context.Context, topic string, body []byte) error {
	c.topic = topic
	c.body = body
	return c.err
}

func TestOpenObserveLoggerPublishesEnvelope(t *testing.T) {
	queue := &captureQueue{}
	now := time.Date(2024, 1, 1, 12, 0, 0, 0, time.UTC)

	logger, err := NewOpenObserveLogger(queue,
		WithLoggerService("slack_bridge"),
		WithLoggerStream("daemon"),
		WithLoggerTopic("observability/logs"),
		WithLoggerEnvelope("observability", "log"),
		WithLoggerTimeSource(func() time.Time { return now }),
	)
	if err != nil {
		t.Fatalf("unexpected error creating logger: %v", err)
	}

	metadata := map[string]any{"module": "worker"}
	if err := logger.Log(context.Background(), "info", "booted", metadata); err != nil {
		t.Fatalf("log returned error: %v", err)
	}

	if queue.topic != "observability/logs" {
		t.Fatalf("expected topic observability/logs, got %s", queue.topic)
	}

	envelope, err := UnmarshalEnvelope(queue.body)
	if err != nil {
		t.Fatalf("failed to decode envelope: %v", err)
	}

	if envelope.Service != "observability" {
		t.Fatalf("unexpected envelope service: %s", envelope.Service)
	}

	if envelope.Metadata["destination"] != "openobserve" {
		t.Fatalf("expected destination metadata to be openobserve")
	}

	entry, ok := envelope.Payload["entry"].(map[string]any)
	if !ok {
		t.Fatalf("payload entry missing")
	}

	if entry["message"] != "booted" {
		t.Fatalf("unexpected message: %v", entry["message"])
	}

	meta, ok := entry["metadata"].(map[string]any)
	if !ok {
		t.Fatalf("expected metadata map in entry")
	}

	if meta["module"] != "worker" {
		t.Fatalf("unexpected metadata module: %v", meta["module"])
	}

	if entry["timestamp"].(string) != now.Format(time.RFC3339Nano) {
		t.Fatalf("unexpected timestamp: %v", entry["timestamp"])
	}
}

func TestOpenObserveLoggerPropagatesPublishError(t *testing.T) {
	queue := &captureQueue{err: errors.New("boom")}
	logger, err := NewOpenObserveLogger(queue)
	if err != nil {
		t.Fatalf("unexpected error creating logger: %v", err)
	}

	err = logger.Log(context.Background(), "info", "oops", nil)
	if err == nil {
		t.Fatalf("expected error from publish")
	}
}

func TestOpenObserveLoggerValidatesInputs(t *testing.T) {
	if _, err := NewOpenObserveLogger(nil); err == nil {
		t.Fatalf("expected error when queue is nil")
	}

	queue := &captureQueue{}
	logger, err := NewOpenObserveLogger(queue)
	if err != nil {
		t.Fatalf("unexpected error creating logger: %v", err)
	}

	if err := logger.Log(context.Background(), "", "msg", nil); err == nil {
		t.Fatalf("expected error for empty level")
	}
}
