/// A headless bot client that:
/// 1. Registers via OTP (auto-verifies using debug_code)
/// 2. Joins a team
/// 3. Listens for messages on all channels
/// 4. Responds with an echo or greeting
///
/// Usage: dart run test_client:bot_client --email bot@msgr.no --team test-team
library;

import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:http/http.dart' as http;

const _baseUrl = 'https://dev.msgr.no';

class BotSession {
  String? accountId;
  String? profileId;
  String? email;

  Map<String, String> get headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (accountId != null) 'X-Account-Id': accountId!,
        if (profileId != null) 'X-Profile-Id': profileId!,
      };

  bool get isLoggedIn => accountId != null && profileId != null;
}

class BotClient {
  BotClient({
    required this.email,
    required this.teamSlug,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String email;
  final String teamSlug;
  final http.Client _client;
  final BotSession _session = BotSession();

  /// Track message IDs we have already seen so we do not echo them again.
  final Set<String> _seenMessageIds = {};

  /// Track channel IDs for the team.
  final List<Map<String, dynamic>> _channels = [];

  // -----------------------------------------------------------------------
  // Auth
  // -----------------------------------------------------------------------

  Future<void> authenticate() async {
    _log('Requesting OTP challenge for $email ...');

    // 1. Request challenge
    final challengeRes = await _client.post(
      Uri.parse('$_baseUrl/api/v1/auth/challenge'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'channel': 'email', 'identifier': email}),
    );
    _assertOk(challengeRes, 'challenge');

    final challengeData = jsonDecode(challengeRes.body) as Map<String, dynamic>;
    final challengeId = challengeData['id'] as String;
    final debugCode = challengeData['debug_code'] as String?;

    if (debugCode == null) {
      _log('ERROR: No debug_code returned. Is the backend in dev mode?');
      exit(1);
    }

    _log('Got challenge $challengeId, debug_code=$debugCode');

    // 2. Verify
    final verifyRes = await _client.post(
      Uri.parse('$_baseUrl/api/v1/auth/verify'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'challenge_id': challengeId, 'code': debugCode}),
    );
    _assertOk(verifyRes, 'verify');

    final verifyData = jsonDecode(verifyRes.body) as Map<String, dynamic>;
    final account = verifyData['account'] as Map<String, dynamic>? ?? {};
    _session.accountId = account['id']?.toString();

    // Get profile ID
    final profileId = verifyData['profile_id']?.toString();
    if (profileId != null && profileId.isNotEmpty) {
      _session.profileId = profileId;
    } else {
      final profiles = account['profiles'] as List? ?? [];
      if (profiles.isNotEmpty) {
        _session.profileId =
            (profiles.first as Map<String, dynamic>)['id']?.toString();
      }
    }
    _session.email = email;

    _log('Authenticated: account=${_session.accountId}, profile=${_session.profileId}');
  }

  // -----------------------------------------------------------------------
  // Team operations
  // -----------------------------------------------------------------------

  Future<void> joinTeam() async {
    _log('Joining team "$teamSlug" ...');
    try {
      final res = await _client.post(
        Uri.parse('$_baseUrl/api/teams/$teamSlug/join'),
        headers: _session.headers,
      );
      if (res.statusCode >= 200 && res.statusCode < 300) {
        _log('Joined team $teamSlug');
      } else if (res.statusCode == 409 || res.statusCode == 422) {
        _log('Already a member of $teamSlug (${res.statusCode})');
      } else {
        _log('Join returned ${res.statusCode}: ${res.body}');
      }
    } catch (e) {
      _log('Join error (may already be member): $e');
    }
  }

  Future<void> fetchChannels() async {
    _log('Fetching channels for $teamSlug ...');
    final res = await _client.get(
      Uri.parse('$_baseUrl/api/teams/$teamSlug/channels'),
      headers: _session.headers,
    );
    _assertOk(res, 'getChannels');

    final decoded = jsonDecode(res.body);
    List<dynamic> channels;
    if (decoded is List) {
      channels = decoded;
    } else if (decoded is Map && decoded['data'] is List) {
      channels = decoded['data'] as List;
    } else {
      channels = [];
    }

    _channels.clear();
    for (final ch in channels) {
      _channels.add(ch as Map<String, dynamic>);
    }
    _log('Found ${_channels.length} channels: ${_channels.map((c) => c['name']).join(', ')}');
  }

  // -----------------------------------------------------------------------
  // Message polling loop
  // -----------------------------------------------------------------------

  Future<void> pollLoop() async {
    _log('Starting message poll loop (every 2s) ...');

    // First pass: record existing messages as "seen" without echoing
    for (final ch in _channels) {
      final channelId = ch['id'].toString();
      final messages = await _fetchMessages(channelId);
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
          final messages = await _fetchMessages(channelId);

          for (final msg in messages) {
            final msgId = msg['id'].toString();
            if (_seenMessageIds.contains(msgId)) continue;
            _seenMessageIds.add(msgId);

            final content = msg['content']?.toString() ?? '';
            final sender = msg['sender'] as Map<String, dynamic>? ?? {};
            final senderName = sender['display_name']?.toString() ??
                sender['name']?.toString() ??
                msg['sender_name']?.toString() ??
                'unknown';
            final senderProfileId = msg['profile_id']?.toString() ??
                sender['id']?.toString() ??
                '';

            _log('[#$channelName] $senderName: $content');

            // Do not echo our own messages
            if (senderProfileId == _session.profileId) continue;

            // Echo the message
            final reply = 'Echo: $content';
            await _sendMessage(channelId, reply);
            _log('[#$channelName] BOT: $reply');
          }
        }
      } catch (e) {
        _log('Poll error: $e');
      }

      await Future<void>.delayed(const Duration(seconds: 2));
    }
  }

  Future<List<Map<String, dynamic>>> _fetchMessages(String channelId) async {
    final res = await _client.get(
      Uri.parse('$_baseUrl/api/teams/$teamSlug/channels/$channelId/messages?limit=20'),
      headers: _session.headers,
    );
    if (res.statusCode < 200 || res.statusCode >= 300) return [];

    final decoded = jsonDecode(res.body);
    List<dynamic> msgs;
    if (decoded is List) {
      msgs = decoded;
    } else if (decoded is Map && decoded['data'] is List) {
      msgs = decoded['data'] as List;
    } else {
      msgs = [];
    }
    return msgs.cast<Map<String, dynamic>>();
  }

  Future<void> _sendMessage(String channelId, String content) async {
    final res = await _client.post(
      Uri.parse('$_baseUrl/api/teams/$teamSlug/channels/$channelId/messages'),
      headers: _session.headers,
      body: jsonEncode({'content': content}),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      _log('Send failed (${res.statusCode}): ${res.body}');
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

  void _assertOk(http.Response res, String label) {
    if (res.statusCode < 200 || res.statusCode >= 300) {
      _log('$label failed with ${res.statusCode}: ${res.body}');
      exit(1);
    }
  }
}

Future<void> main(List<String> args) async {
  final parser = ArgParser()
    ..addOption('email',
        abbr: 'e', help: 'Bot email address', defaultsTo: 'bot@msgr.no')
    ..addOption('team',
        abbr: 't', help: 'Team slug to join', defaultsTo: 'test-team')
    ..addFlag('help', abbr: 'h', negatable: false);

  final results = parser.parse(args);
  if (results['help'] as bool) {
    print('Usage: dart run test_client:bot_client [options]');
    print(parser.usage);
    exit(0);
  }

  final email = results['email'] as String;
  final team = results['team'] as String;

  print('=== Msgr Bot Client ===');
  print('Email: $email');
  print('Team:  $team');
  print('');

  final bot = BotClient(email: email, teamSlug: team);

  await bot.authenticate();
  await bot.joinTeam();
  await bot.fetchChannels();
  await bot.pollLoop();
}
