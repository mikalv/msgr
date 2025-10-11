package msgrbridge

import "context"

// QueueMessageHandler processes a StoneMQ message payload.
type QueueMessageHandler func(context.Context, []byte) error

// QueueClient represents the minimal contract the SDK requires from a StoneMQ client.
type QueueClient interface {
	Subscribe(ctx context.Context, topic string, handler QueueMessageHandler) error
	Publish(ctx context.Context, topic string, body []byte) error
}

// Topic returns the canonical queue topic for a service/action pair.
func Topic(service, action string) string {
	return "bridge/" + service + "/" + action
}
