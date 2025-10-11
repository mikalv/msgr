package msgrbridge

import (
	"context"
	"errors"
	"time"
)

type timeSource func() time.Time

// OpenObserveLogger publishes structured log entries to StoneMQ so they can be ingested by OpenObserve.
type OpenObserveLogger struct {
	queue           QueueClient
	service         string
	stream          string
	topic           string
	envelopeService string
	envelopeAction  string
	now             timeSource
}

// OpenObserveLoggerOption mutates the logger configuration.
type OpenObserveLoggerOption func(*OpenObserveLogger) error

// NewOpenObserveLogger constructs a logger that emits envelopes to the provided queue client.
func NewOpenObserveLogger(queue QueueClient, opts ...OpenObserveLoggerOption) (*OpenObserveLogger, error) {
	if queue == nil {
		return nil, errors.New("queue client must not be nil")
	}

	logger := &OpenObserveLogger{
		queue:           queue,
		service:         "bridge_daemon",
		stream:          "daemon",
		topic:           "observability/logs",
		envelopeService: "observability",
		envelopeAction:  "log",
		now: func() time.Time {
			return time.Now().UTC().Truncate(time.Millisecond)
		},
	}

	for _, opt := range opts {
		if err := opt(logger); err != nil {
			return nil, err
		}
	}

	return logger, nil
}

// WithLoggerService overrides the service name attached to log entries.
func WithLoggerService(service string) OpenObserveLoggerOption {
	return func(l *OpenObserveLogger) error {
		if service == "" {
			return errors.New("service must not be empty")
		}
		l.service = service
		return nil
	}
}

// WithLoggerStream overrides the observability stream metadata.
func WithLoggerStream(stream string) OpenObserveLoggerOption {
	return func(l *OpenObserveLogger) error {
		if stream == "" {
			return errors.New("stream must not be empty")
		}
		l.stream = stream
		return nil
	}
}

// WithLoggerTopic overrides the StoneMQ topic used for log forwarding.
func WithLoggerTopic(topic string) OpenObserveLoggerOption {
	return func(l *OpenObserveLogger) error {
		if topic == "" {
			return errors.New("topic must not be empty")
		}
		l.topic = topic
		return nil
	}
}

// WithLoggerEnvelope overrides the envelope routing metadata.
func WithLoggerEnvelope(service, action string) OpenObserveLoggerOption {
	return func(l *OpenObserveLogger) error {
		if service == "" {
			return errors.New("envelope service must not be empty")
		}
		if action == "" {
			return errors.New("envelope action must not be empty")
		}
		l.envelopeService = service
		l.envelopeAction = action
		return nil
	}
}

// WithLoggerTimeSource injects a deterministic clock for tests.
func WithLoggerTimeSource(source timeSource) OpenObserveLoggerOption {
	return func(l *OpenObserveLogger) error {
		if source == nil {
			return errors.New("time source must not be nil")
		}
		l.now = source
		return nil
	}
}

// Log publishes a structured log entry to the StoneMQ topic.
func (l *OpenObserveLogger) Log(ctx context.Context, level, message string, metadata map[string]any) error {
	if l == nil {
		return errors.New("logger must not be nil")
	}
	if level == "" {
		return errors.New("level must not be empty")
	}

	occurredAt := l.now().UTC().Truncate(time.Millisecond)

	entry := map[string]any{
		"level":     level,
		"message":   message,
		"service":   l.service,
		"timestamp": occurredAt.Format(time.RFC3339Nano),
	}

	if len(metadata) > 0 {
		copy := make(map[string]any, len(metadata))
		for key, value := range metadata {
			copy[key] = value
		}
		entry["metadata"] = copy
	}

	envelopeMetadata := map[string]any{
		"destination": "openobserve",
		"stream":      l.stream,
		"service":     l.service,
	}

	payload := map[string]any{
		"entry": entry,
	}

	envelope, err := NewEnvelope(
		l.envelopeService,
		l.envelopeAction,
		payload,
		WithMetadata(envelopeMetadata),
		WithOccurredAt(occurredAt),
	)
	if err != nil {
		return err
	}

	body, err := envelope.MarshalBinary()
	if err != nil {
		return err
	}

	return l.queue.Publish(ctx, l.topic, body)
}
