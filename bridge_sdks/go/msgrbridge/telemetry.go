package msgrbridge

import "time"

// TelemetryReporter records queue handling metrics.
type TelemetryReporter interface {
	RecordDelivery(service, action string, duration time.Duration, outcome string)
}

// NoopTelemetry is a TelemetryReporter that discards metrics.
type NoopTelemetry struct{}

// RecordDelivery implements TelemetryReporter.
func (NoopTelemetry) RecordDelivery(service, action string, duration time.Duration, outcome string) {}
