package msgrbridge

import (
	"context"
	"sync"
	"testing"
	"time"
)

type memoryQueue struct {
	mu            sync.Mutex
	subscriptions map[string]QueueMessageHandler
}

func (m *memoryQueue) Subscribe(ctx context.Context, topic string, handler QueueMessageHandler) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	if m.subscriptions == nil {
		m.subscriptions = map[string]QueueMessageHandler{}
	}
	m.subscriptions[topic] = handler
	return nil
}

func (m *memoryQueue) Publish(ctx context.Context, topic string, body []byte) error {
	m.mu.Lock()
	handler := m.subscriptions[topic]
	m.mu.Unlock()
	if handler == nil {
		return nil
	}
	return handler(ctx, body)
}

type recordingTelemetry struct {
	mu      sync.Mutex
	entries []string
}

func (r *recordingTelemetry) RecordDelivery(service, action string, duration time.Duration, outcome string) {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.entries = append(r.entries, service+":"+action+":"+outcome)
}

type recordingBootstrapper struct {
	called bool
}

func (r *recordingBootstrapper) Bootstrap(ctx context.Context, service string) (map[string]any, error) {
	r.called = true
	return map[string]any{}, nil
}

func TestDaemonStartRegistersHandlers(t *testing.T) {
	queue := &memoryQueue{}
	telemetry := &recordingTelemetry{}
	bootstrapper := &recordingBootstrapper{}

	daemon, err := NewDaemon("telegram", queue, WithTelemetry(telemetry), WithCredentialBootstrapper(bootstrapper))
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	handled := make(chan Envelope, 1)
	daemon.Register("inbound_event", func(ctx context.Context, env Envelope) error {
		handled <- env
		return nil
	})

	if err := daemon.Start(context.Background()); err != nil {
		t.Fatalf("start error: %v", err)
	}

	if !bootstrapper.called {
		t.Fatalf("expected bootstrapper to be invoked")
	}

	env, err := NewEnvelope("telegram", "inbound_event", map[string]any{"body": "hi"}, WithTraceID("trace"))
	if err != nil {
		t.Fatalf("envelope error: %v", err)
	}
	data, _ := env.MarshalBinary()

	if err := queue.Publish(context.Background(), Topic("telegram", "inbound_event"), data); err != nil {
		t.Fatalf("publish error: %v", err)
	}

	select {
	case <-time.After(time.Second):
		t.Fatalf("handler was not invoked")
	case env := <-handled:
		if env.TraceID != "trace" {
			t.Fatalf("unexpected envelope: %v", env)
		}
	}

	if len(telemetry.entries) == 0 {
		t.Fatalf("expected telemetry to record delivery")
	}
}

func TestDaemonStartRequiresHandlers(t *testing.T) {
	queue := &memoryQueue{}
	daemon, err := NewDaemon("slack", queue)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	if err := daemon.Start(context.Background()); err == nil {
		t.Fatalf("expected error when no handlers registered")
	}
}
