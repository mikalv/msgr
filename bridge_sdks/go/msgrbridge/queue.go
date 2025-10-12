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
	return buildTopic(service, action, "")
}

// TopicForInstance returns the queue topic for a service/action scoped to a specific bridge instance.
func TopicForInstance(service, instance, action string) string {
	return buildTopic(service, action, instance)
}

func buildTopic(service, action, instance string) string {
	if instance == "" {
		return "bridge/" + service + "/" + action
	}

	return "bridge/" + service + "/" + instance + "/" + action
}
