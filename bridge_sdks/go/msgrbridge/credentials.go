package msgrbridge

import (
	"context"
	"encoding/json"
	"os"
	"strings"
)

// CredentialBootstrapper prepares a daemon with credential material.
type CredentialBootstrapper interface {
	Bootstrap(ctx context.Context, service string) (map[string]any, error)
}

// EnvCredentialBootstrapper loads credentials from environment variables.
type EnvCredentialBootstrapper struct {
	Loader func(string) string
}

// NewEnvCredentialBootstrapper returns a bootstrapper using os.LookupEnv.
func NewEnvCredentialBootstrapper() EnvCredentialBootstrapper {
	return EnvCredentialBootstrapper{Loader: func(key string) string {
		return lookupEnv(key)
	}}
}

// Bootstrap implements CredentialBootstrapper.
func (b EnvCredentialBootstrapper) Bootstrap(ctx context.Context, service string) (map[string]any, error) {
	key := "MSGR_" + strings.ToUpper(service) + "_CREDENTIALS"
	raw := b.Loader(key)
	if raw == "" {
		return map[string]any{}, nil
	}

	var payload map[string]any
	if err := json.Unmarshal([]byte(raw), &payload); err != nil {
		return nil, err
	}

	return payload, nil
}

// lookupEnv is overridden in tests.
var lookupEnv = func(key string) string {
	value, _ := os.LookupEnv(key)
	return value
}
