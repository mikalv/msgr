/// A headless bot client that:
/// 1. Registers via OTP (auto-verifies using debug_code)
/// 2. Joins a team
/// 3. Listens for messages on all channels via Phoenix WebSocket
/// 4. Responds with an echo or greeting
///
/// Usage: dart run test_client:bot_client --email bot@msgr.no --team test-team
library;

import 'dart:io';

import 'package:args/args.dart';
import 'package:libmsgr/api.dart';

const _baseUrl = 'https://dev.msgr.no';

class BotClient {
  BotClient({
    required this.email,
    required this.teamSlug,
  });

  final String email;
  final String teamSlug;
  late final MsgrClient _client;

  /// Channel IDs we are monitoring.
  final List<Map<String, dynamic>> _channels = [];

  /// Track message IDs we have already seen so we do not echo them again.
  final Set<String> _seenMessageIds = {};

  // -----------------------------------------------------------------------
  // Auth -- uses libmsgr MsgrApiClient
  // -----------------------------------------------------------------------

  Future<void> authenticate() async {
    _log('Requesting OTP challenge for $email ...');

    _client = MsgrClient(baseUrl: _baseUrl);

    // 1. Request challenge
    final challenge =
        await _client.api.requestChallenge(email, channel: 'email');
    final debugCode = challenge.debugCode;

    if (debugCode == null) {
      _log('ERROR: No debug_code returned. Is the backend in dev mode?');
      exit(1);
    }

    _log('Got challenge ${challenge.id}, debug_code=$debugCode');

    // 2. Verify
    final session = await _client.api.verifyCode(challenge.id, debugCode);
    _client.setSession(session);

    _log('Authenticated: account=${session.accountId}, profile=${session.profileId}');
  }

  // -----------------------------------------------------------------------
  // Team operations -- uses libmsgr MsgrApiClient
  // -----------------------------------------------------------------------

  Future<void> joinTeam() async {
    _log('Joining team "$teamSlug" ...');
    try {
      await _client.api.joinTeam(teamSlug);
      _log('Joined team $teamSlug');
    } catch (e) {
      _log('Join error (may already be member): $e');
    }
  }

  Future<void> fetchChannels() async {
    _log('Fetching channels for $teamSlug ...');
    final channels = await _client.api.getChannels(teamSlug);
    _channels.clear();
    _channels.addAll(channels);
    _log('Found ${_channels.length} channels: ${_channels.map((c) => c['name']).join(', ')}');
  }

  // -----------------------------------------------------------------------
  // Real-time: connect Phoenix WebSocket and listen for messages
  // -----------------------------------------------------------------------

  Future<void> connectRealtime() async {
    _log('Connecting WebSocket ...');
    await _client.connectRealtime();

    // Wire up event handler
    _client.realtime.onEvent = _handleRealtimeEvent;
    _client.realtime.onDisconnect = () => _log('WebSocket disconnected');
    _client.realtime.onReconnect = () => _log('WebSocket reconnected');

    // Join all channel topics
    for (final ch in _channels) {
      final channelId = ch['id'].toString();
      final topic = 'channel:$teamSlug.$channelId';
      await _client.realtime.join(topic);
      _log('Joined topic: $topic');
    }

    // Also join the lobby
    await _client.realtime.join('channel:lobby');
    _log('WebSocket connected and channels joined');
  }

  void _handleRealtimeEvent(
      String topic, String event, Map<String, dynamic> payload) {
    if (event == 'new:msg' || event == 'create:msg') {
      final msgId = payload['id']?.toString() ?? '';
      if (_seenMessageIds.contains(msgId)) return;
      _seenMessageIds.add(msgId);

      final content = payload['content']?.toString() ?? '';
      final senderProfileId = payload['profile_id']?.toString() ??
          (payload['sender'] as Map<String, dynamic>?)?['id']?.toString() ??
          '';
      final senderName =
          (payload['sender'] as Map<String, dynamic>?)?['display_name']
                  ?.toString() ??
              payload['sender_name']?.toString() ??
              'unknown';

      _log('[$topic] $senderName: $content');

      // Do not echo our own messages
      if (senderProfileId == _client.profileId) return;

      // Extract channel info from topic and echo
      final parts = topic.split(':');
      if (parts.length >= 2) {
        final channelRef = parts[1]; // "teamSlug.channelId"
        final channelParts = channelRef.split('.');
        if (channelParts.length >= 2) {
          final channelId = channelParts[1];
          final reply = 'Echo: $content';
          _client.api.sendMessage(teamSlug, channelId, reply).then((_) {
            _log('[$topic] BOT: $reply');
          }).catchError((e) {
            _log('Send error: $e');
          });
        }
      }
    }
  }

  // -----------------------------------------------------------------------
  // Fallback poll loop (if WebSocket is not available)
  // -----------------------------------------------------------------------

  Future<void> pollLoop() async {
    _log('Starting message poll loop (every 2s) ...');

    // First pass: record existing messages as "seen" without echoing
    for (final ch in _channels) {
      final channelId = ch['id'].toString();
      final messages =
          await _client.api.getMessages(teamSlug, channelId, limit: 20);
      for (final msg in messages) {
        _seenMessageIds.add(msg['id'].toString());
      }
    }
    _log('Indexed ${_seenMessageIds.length} existing messages');

    while (true) {
      try {
        for (final ch in _channels) {
          final channelId = ch['id'].toString();
          final channelName = ch['name']?.toString() ?? channelId;
          final messages =
              await _client.api.getMessages(teamSlug, channelId, limit: 20);

          for (final msg in messages) {
            final msgId = msg['id'].toString();
            if (_seenMessageIds.contains(msgId)) continue;
            _seenMessageIds.add(msgId);

            final content = msg['content']?.toString() ?? '';
            final sender =
                msg['sender'] as Map<String, dynamic>? ?? {};
            final senderName = sender['display_name']?.toString() ??
                sender['name']?.toString() ??
                msg['sender_name']?.toString() ??
                'unknown';
            final senderProfileId = msg['profile_id']?.toString() ??
                sender['id']?.toString() ??
                '';

            _log('[#$channelName] $senderName: $content');

            // Do not echo our own messages
            if (senderProfileId == _client.profileId) continue;

            // Echo the message
            final reply = 'Echo: $content';
            await _client.api.sendMessage(teamSlug, channelId, reply);
            _log('[#$channelName] BOT: $reply');
          }
        }
      } catch (e) {
        _log('Poll error: $e');
      }

      await Future<void>.delayed(const Duration(seconds: 2));
    }
  }

  // -----------------------------------------------------------------------
  // Helpers
  // -----------------------------------------------------------------------

  void _log(String message) {
    final now = DateTime.now();
    final ts =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
    print('[$ts] $message');
  }
}

Future<void> main(List<String> args) async {
  final parser = ArgParser()
    ..addOption('email',
        abbr: 'e', help: 'Bot email address', defaultsTo: 'bot@msgr.no')
    ..addOption('team',
        abbr: 't', help: 'Team slug to join', defaultsTo: 'test-team')
    ..addFlag('poll',
        abbr: 'p',
        help: 'Use polling instead of WebSocket',
        negatable: false)
    ..addFlag('help', abbr: 'h', negatable: false);

  final results = parser.parse(args);
  if (results['help'] as bool) {
    print('Usage: dart run test_client:bot_client [options]');
    print(parser.usage);
    exit(0);
  }

  final email = results['email'] as String;
  final team = results['team'] as String;
  final usePoll = results['poll'] as bool;

  print('=== Msgr Bot Client ===');
  print('Email: $email');
  print('Team:  $team');
  print('Mode:  ${usePoll ? "polling" : "WebSocket"}');
  print('');

  final bot = BotClient(email: email, teamSlug: team);

  await bot.authenticate();
  await bot.joinTeam();
  await bot.fetchChannels();

  if (usePoll) {
    await bot.pollLoop();
  } else {
    await bot.connectRealtime();
    // Keep the process alive while WebSocket is running.
    await Future<void>.delayed(const Duration(days: 365));
  }
}
