import 'dart:convert';
import 'package:http/http.dart' as http;

/// A message in a chat completion request.
class ChatMessage {
  const ChatMessage({required this.role, required this.content});

  /// Role: "system", "user", or "assistant".
  final String role;

  /// The message content.
  final String content;

  Map<String, String> toJson() => {'role': role, 'content': content};
}

/// OpenAI-compatible LLM client that works with any compatible proxy.
class LlmClient {
  LlmClient({
    required this.baseUrl,
    required this.apiKey,
    this.model = 'claude-sonnet-4-20250514',
  });

  final String baseUrl;
  final String apiKey;
  final String model;

  /// Send a chat completion request and return the assistant's reply.
  Future<String> chat(
    List<ChatMessage> messages, {
    String? systemPrompt,
    int maxTokens = 1024,
  }) async {
    final allMessages = <ChatMessage>[
      if (systemPrompt != null)
        ChatMessage(role: 'system', content: systemPrompt),
      ...messages,
    ];

    final body = jsonEncode({
      'model': model,
      'messages': allMessages.map((m) => m.toJson()).toList(),
      'max_tokens': maxTokens,
    });

    final uri = Uri.parse('$baseUrl/v1/chat/completions');
    print('[LLM] POST $uri model=$model messages=${allMessages.length}');
    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: body,
    );

    print('[LLM] Response: ${response.statusCode} (${response.body.length} bytes)');
    if (response.statusCode != 200) {
      throw LlmException(
        'LLM request failed (${response.statusCode}): ${response.body}',
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final choices = json['choices'] as List<dynamic>? ?? [];
    if (choices.isEmpty) {
      throw LlmException('LLM returned empty choices: ${response.body}');
    }

    final message = choices[0]['message'] as Map<String, dynamic>? ?? {};
    final content = message['content']?.toString() ?? '';

    // Strip <think>...</think> tags from reasoning models
    final stripped = content.replaceAll(RegExp(r'<think>[\s\S]*?</think>'), '').trim();
    print('[LLM] Reply (${stripped.length} chars): ${stripped.substring(0, stripped.length.clamp(0, 80))}...');

    if (stripped.isEmpty) {
      throw LlmException('LLM returned empty content after stripping think tags');
    }

    return stripped;
  }
}

class LlmException implements Exception {
  LlmException(this.message);
  final String message;

  @override
  String toString() => 'LlmException: $message';
}
