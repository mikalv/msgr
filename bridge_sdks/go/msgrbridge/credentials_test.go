package msgrbridge

import (
	"context"
	"testing"
)

func TestEnvCredentialBootstrapperReturnsEmptyMapWhenMissing(t *testing.T) {
	bootstrapper := EnvCredentialBootstrapper{Loader: func(string) string { return "" }}
	creds, err := bootstrapper.Bootstrap(context.Background(), "slack")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(creds) != 0 {
		t.Fatalf("expected empty credentials, got %v", creds)
	}
}

func TestEnvCredentialBootstrapperParsesJSON(t *testing.T) {
	bootstrapper := EnvCredentialBootstrapper{Loader: func(string) string { return `{"token":"abc"}` }}
	creds, err := bootstrapper.Bootstrap(context.Background(), "discord")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if creds["token"].(string) != "abc" {
		t.Fatalf("unexpected credentials: %v", creds)
	}
}

func TestEnvCredentialBootstrapperErrorsOnInvalidJSON(t *testing.T) {
	bootstrapper := EnvCredentialBootstrapper{Loader: func(string) string { return "{" }}
	if _, err := bootstrapper.Bootstrap(context.Background(), "discord"); err == nil {
		t.Fatalf("expected error")
	}
}
