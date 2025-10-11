package msgrbridge

import (
	"encoding/json"
	"testing"
	"time"
)

func TestNewEnvelopeDefaults(t *testing.T) {
	payload := map[string]any{"body": "hi"}
	env, err := NewEnvelope("discord", "send", payload)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	if env.Schema != DefaultSchema {
		t.Fatalf("expected schema %s got %s", DefaultSchema, env.Schema)
	}
	if env.Service != "discord" {
		t.Fatalf("unexpected service: %s", env.Service)
	}
	if env.Action != "send" {
		t.Fatalf("unexpected action: %s", env.Action)
	}
	if env.TraceID == "" {
		t.Fatalf("trace id should be generated")
	}
	if env.Metadata == nil {
		t.Fatalf("metadata should default to empty map")
	}
	if env.OccurredAt.Location() != time.UTC {
		t.Fatalf("occurred_at should be in UTC")
	}
}

func TestEnvelopeOptions(t *testing.T) {
	now := time.Now().Add(-time.Minute)
	env, err := NewEnvelope("slack", "sync", map[string]any{},
		WithTraceID("trace"),
		WithMetadata(map[string]any{"retries": 1}),
		WithSchema("msgr.bridge.v2"),
		WithOccurredAt(now),
	)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	if env.TraceID != "trace" {
		t.Fatalf("unexpected trace id: %s", env.TraceID)
	}
	if env.Schema != "msgr.bridge.v2" {
		t.Fatalf("unexpected schema: %s", env.Schema)
	}
	if env.Metadata["retries"].(int) != 1 {
		t.Fatalf("metadata not applied")
	}
	if !env.OccurredAt.Equal(now.UTC().Truncate(time.Millisecond)) {
		t.Fatalf("occurred_at not truncated")
	}
}

func TestMarshalAndUnmarshalEnvelope(t *testing.T) {
	env, err := NewEnvelope("snapchat", "inbound_event", map[string]any{"body": "hi"}, WithTraceID("trace"))
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	data, err := env.MarshalBinary()
	if err != nil {
		t.Fatalf("marshal error: %v", err)
	}

	decoded, err := UnmarshalEnvelope(data)
	if err != nil {
		t.Fatalf("unmarshal error: %v", err)
	}

	if decoded.TraceID != "trace" {
		t.Fatalf("trace id mismatch: %s", decoded.TraceID)
	}
	if decoded.Service != env.Service || decoded.Action != env.Action {
		t.Fatalf("service/action mismatch")
	}
}

func TestUnmarshalRejectsInvalidJSON(t *testing.T) {
	if _, err := UnmarshalEnvelope([]byte("{")); err == nil {
		t.Fatalf("expected error for invalid json")
	}
}

func TestNewEnvelopeRequiresPayload(t *testing.T) {
	if _, err := NewEnvelope("discord", "send", nil); err == nil {
		t.Fatalf("expected error when payload is nil")
	}
}

func TestMarshalSerialisesOccurredAt(t *testing.T) {
	env, err := NewEnvelope("discord", "send", map[string]any{}, WithTraceID("trace"))
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	data, err := env.MarshalBinary()
	if err != nil {
		t.Fatalf("marshal error: %v", err)
	}

	var raw map[string]any
	if err := json.Unmarshal(data, &raw); err != nil {
		t.Fatalf("json error: %v", err)
	}

	if _, ok := raw["occurred_at"].(string); !ok {
		t.Fatalf("occurred_at should be serialised as string")
	}
}
