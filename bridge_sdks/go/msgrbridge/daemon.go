package msgrbridge

import (
	"context"
	"fmt"
	"sync"
	"time"
)

// Handler consumes an envelope after it has been decoded.
type Handler func(context.Context, Envelope) error

// Daemon wires queue subscriptions, credential bootstrap and telemetry.
type Daemon struct {
	service      string
	queue        QueueClient
	telemetry    TelemetryReporter
	credentials  CredentialBootstrapper
	handlers     map[string]Handler
	handlerMutex sync.RWMutex
}

// DaemonOption configures the daemon.
type DaemonOption func(*Daemon)

// WithTelemetry sets a telemetry reporter.
func WithTelemetry(reporter TelemetryReporter) DaemonOption {
	return func(d *Daemon) {
		d.telemetry = reporter
	}
}

// WithCredentialBootstrapper injects a credential bootstrapper.
func WithCredentialBootstrapper(bootstrapper CredentialBootstrapper) DaemonOption {
	return func(d *Daemon) {
		d.credentials = bootstrapper
	}
}

// NewDaemon constructs a daemon for a given service.
func NewDaemon(service string, queue QueueClient, opts ...DaemonOption) (*Daemon, error) {
	if service == "" {
		return nil, fmt.Errorf("service must not be empty")
	}
	if queue == nil {
		return nil, fmt.Errorf("queue client is required")
	}

	daemon := &Daemon{
		service:   service,
		queue:     queue,
		telemetry: NoopTelemetry{},
		handlers:  map[string]Handler{},
	}

	for _, opt := range opts {
		opt(daemon)
	}

	return daemon, nil
}

// Register associates a queue action with a handler.
func (d *Daemon) Register(action string, handler Handler) {
	d.handlerMutex.Lock()
	defer d.handlerMutex.Unlock()
	d.handlers[action] = handler
}

// Start subscribes handlers and performs credential bootstrap.
func (d *Daemon) Start(ctx context.Context) error {
	if d.credentials != nil {
		if _, err := d.credentials.Bootstrap(ctx, d.service); err != nil {
			return fmt.Errorf("credential bootstrap failed: %w", err)
		}
	}

	d.handlerMutex.RLock()
	defer d.handlerMutex.RUnlock()

	if len(d.handlers) == 0 {
		return fmt.Errorf("no handlers registered")
	}

	for action, handler := range d.handlers {
		action := action
		handler := handler
		if err := d.queue.Subscribe(ctx, Topic(d.service, action), d.wrapHandler(action, handler)); err != nil {
			return fmt.Errorf("subscribe %s: %w", action, err)
		}
	}

	return nil
}

func (d *Daemon) wrapHandler(action string, handler Handler) QueueMessageHandler {
	return func(ctx context.Context, body []byte) error {
		start := time.Now()
		outcome := "ok"

		env, err := UnmarshalEnvelope(body)
		if err != nil {
			outcome = "decode_error"
			d.telemetry.RecordDelivery(d.service, action, time.Since(start), outcome)
			return err
		}

		if err := handler(ctx, env); err != nil {
			outcome = "handler_error"
			d.telemetry.RecordDelivery(d.service, action, time.Since(start), outcome)
			return err
		}

		d.telemetry.RecordDelivery(d.service, action, time.Since(start), outcome)
		return nil
	}
}
