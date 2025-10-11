package msgrbridge

import (
	"encoding/json"
	"errors"
	"time"

	"github.com/google/uuid"
)

const (
	// DefaultSchema is the canonical schema identifier shared with the Elixir helpers.
	DefaultSchema = "msgr.bridge.v1"
)

// Envelope is the canonical StoneMQ payload.
type Envelope struct {
	Schema     string         `json:"schema"`
	Service    string         `json:"service"`
	Action     string         `json:"action"`
	TraceID    string         `json:"trace_id"`
	OccurredAt time.Time      `json:"occurred_at"`
	Metadata   map[string]any `json:"metadata"`
	Payload    map[string]any `json:"payload"`
}

// EnvelopeOption mutates the envelope at construction time.
type EnvelopeOption func(*Envelope) error

// WithTraceID overrides the generated trace identifier.
func WithTraceID(traceID string) EnvelopeOption {
	return func(e *Envelope) error {
		if traceID == "" {
			return errors.New("traceID must not be empty")
		}
		e.TraceID = traceID
		return nil
	}
}

// WithMetadata sets metadata, copying the provided map.
func WithMetadata(metadata map[string]any) EnvelopeOption {
	return func(e *Envelope) error {
		if metadata == nil {
			e.Metadata = map[string]any{}
			return nil
		}
		copy := make(map[string]any, len(metadata))
		for key, value := range metadata {
			copy[key] = value
		}
		e.Metadata = copy
		return nil
	}
}

// WithOccurredAt overrides the timestamp for deterministic tests.
func WithOccurredAt(t time.Time) EnvelopeOption {
	return func(e *Envelope) error {
		e.OccurredAt = t.UTC().Truncate(time.Millisecond)
		return nil
	}
}

// WithSchema lets callers opt into experimental schemas.
func WithSchema(schema string) EnvelopeOption {
	return func(e *Envelope) error {
		if schema == "" {
			return errors.New("schema must not be empty")
		}
		e.Schema = schema
		return nil
	}
}

// NewEnvelope constructs the canonical envelope while validating input.
func NewEnvelope(service, action string, payload map[string]any, opts ...EnvelopeOption) (Envelope, error) {
	if service == "" {
		return Envelope{}, errors.New("service must not be empty")
	}
	if action == "" {
		return Envelope{}, errors.New("action must not be empty")
	}
	if payload == nil {
		return Envelope{}, errors.New("payload must not be nil")
	}

	envelope := Envelope{
		Schema:     DefaultSchema,
		Service:    service,
		Action:     action,
		TraceID:    uuid.NewString(),
		OccurredAt: time.Now().UTC().Truncate(time.Millisecond),
		Metadata:   map[string]any{},
		Payload:    payload,
	}

	for _, opt := range opts {
		if err := opt(&envelope); err != nil {
			return Envelope{}, err
		}
	}

	return envelope, nil
}

// MarshalBinary encodes the envelope to JSON for queue publication.
func (e Envelope) MarshalBinary() ([]byte, error) {
	type alias Envelope
	return json.Marshal(struct {
		OccurredAt string `json:"occurred_at"`
		alias
	}{
		OccurredAt: e.OccurredAt.UTC().Format(time.RFC3339Nano),
		alias:      alias(e),
	})
}

// UnmarshalEnvelope decodes JSON into an Envelope.
func UnmarshalEnvelope(data []byte) (Envelope, error) {
	type envelopeJSON struct {
		Schema     string         `json:"schema"`
		Service    string         `json:"service"`
		Action     string         `json:"action"`
		TraceID    string         `json:"trace_id"`
		OccurredAt string         `json:"occurred_at"`
		Metadata   map[string]any `json:"metadata"`
		Payload    map[string]any `json:"payload"`
	}

	var raw envelopeJSON
	if err := json.Unmarshal(data, &raw); err != nil {
		return Envelope{}, err
	}

	if raw.Metadata == nil {
		raw.Metadata = map[string]any{}
	}
	if raw.Payload == nil {
		raw.Payload = map[string]any{}
	}

	occurredAt, err := time.Parse(time.RFC3339Nano, raw.OccurredAt)
	if err != nil {
		return Envelope{}, err
	}

	env, err := NewEnvelope(raw.Service, raw.Action, raw.Payload,
		WithSchema(defaultString(raw.Schema, DefaultSchema)),
		WithTraceID(raw.TraceID),
		WithMetadata(raw.Metadata),
		WithOccurredAt(occurredAt),
	)
	if err != nil {
		return Envelope{}, err
	}

	return env, nil
}

func defaultString(value string, fallback string) string {
	if value == "" {
		return fallback
	}
	return value
}
