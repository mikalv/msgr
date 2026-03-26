import 'dart:async';
import 'dart:io';

import 'package:args/args.dart';
import 'package:llm_agent/llm_agent.dart';

/// Kåre — a hippie chatbot for Msgr
///
/// Usage:
///   dart run llm_agent:kaare \
///     --email kaare@msgr.no \
///     --team bekkevoll \
///     --llm-url https://llmproxy.rprxy.mdma.sh \
///     --llm-key YOUR_API_KEY \
///     --model claude-sonnet-4-20250514
///
/// Environment variables (alternative to flags):
///   LLM_PROXY_URL, LLM_API_KEY, LLM_MODEL
void main(List<String> args) async {
  final parser = ArgParser()
    ..addOption('email', defaultsTo: 'kaare@msgr.no', help: 'Bot email')
    ..addOption('team', mandatory: true, help: 'Team slug to join')
    ..addOption('msgr-url',
        defaultsTo:
            Platform.environment['MSGR_BASE_URL'] ?? 'https://dev.msgr.no',
        help: 'Msgr API base URL')
    ..addOption('llm-url',
        defaultsTo: Platform.environment['LLM_PROXY_URL'] ??
            'https://llmproxy.rprxy.mdma.sh',
        help: 'LLM proxy base URL')
    ..addOption('llm-key',
        defaultsTo: Platform.environment['LLM_API_KEY'],
        help: 'LLM API key')
    ..addOption('model',
        defaultsTo:
            Platform.environment['LLM_MODEL'] ?? 'claude-sonnet-4-20250514',
        help: 'LLM model name')
    ..addOption('bot-secret',
        defaultsTo: Platform.environment['MSGR_BOT_SECRET'],
        help: 'Bot authentication secret')
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Show usage');

  final ArgResults results;
  try {
    results = parser.parse(args);
  } on FormatException catch (e) {
    print('[Kåre] $e');
    print('Usage: dart run llm_agent:kaare [options]');
    print(parser.usage);
    exit(1);
  }

  if (results['help'] as bool) {
    print('Kåre — hippie chatbot for Msgr');
    print('');
    print('Usage: dart run llm_agent:kaare [options]');
    print(parser.usage);
    exit(0);
  }

  final llmKey = results['llm-key'] as String?;
  if (llmKey == null || llmKey.isEmpty) {
    print('[Kåre] Feil: LLM API-nøkkel mangler.');
    print('       Bruk --llm-key eller sett LLM_API_KEY.');
    exit(1);
  }

  final botSecret = results['bot-secret'] as String?;
  if (botSecret == null || botSecret.isEmpty) {
    print('[Kåre] Feil: Bot-secret mangler.');
    print('       Bruk --bot-secret eller sett MSGR_BOT_SECRET.');
    exit(1);
  }

  final llmClient = LlmClient(
    baseUrl: results['llm-url'] as String,
    apiKey: llmKey,
    model: results['model'] as String,
  );

  // Keep recent messages per channel for context
  final channelHistory = <String, List<BotMessage>>{};

  late final MsgrBot bot;
  bot = MsgrBot(
    email: results['email'] as String,
    teamSlug: results['team'] as String,
    botSecret: botSecret,
    msgrBaseUrl: results['msgr-url'] as String,
    onMessage: (message) async {
      // Don't reply to own messages
      if (message.senderProfileId == bot.teamProfileId) return null;

      // Use thread-specific or channel-specific history
      final contextKey = message.threadParentId ?? message.channelId;
      channelHistory.putIfAbsent(contextKey, () => []);
      channelHistory[contextKey]!.add(message);

      // Keep last 20 messages per context
      if (channelHistory[contextKey]!.length > 20) {
        channelHistory[contextKey] =
            channelHistory[contextKey]!.sublist(
          channelHistory[contextKey]!.length - 20,
        );
      }

      // Build context and get LLM response
      final messages = KaarePersona.buildMessages(
        channelHistory[contextKey]!,
        message,
      );

      try {
        final reply = await llmClient.chat(messages);

        // Add own reply to history so future context includes it
        channelHistory[contextKey]!.add(BotMessage(
          channelId: message.channelId,
          channelName: message.channelName,
          senderName: 'kaare',
          senderProfileId: bot.teamProfileId ?? '',
          content: reply,
          messageId: 'self-${DateTime.now().microsecondsSinceEpoch}',
          timestamp: DateTime.now(),
        ));

        return reply;
      } catch (e) {
        print('[Kåre] LLM-feil: $e');
        return 'Oi manne, hjernen min tok seg en liten Woodstock-pause der... ✌️';
      }
    },
  );

  print('[Kåre] Starter opp... Fred og kjærlighet til alle!');

  try {
    await bot.start();
  } catch (e) {
    print('[Kåre] Feil ved oppstart: $e');
    exit(1);
  }

  // Keep the process alive
  await Completer<void>().future;
}
