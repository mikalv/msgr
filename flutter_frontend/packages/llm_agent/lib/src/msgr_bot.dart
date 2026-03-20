import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

/// A headless Msgr bot that authenticates via OTP, joins a team, and polls for messages.
class MsgrBot {
  MsgrBot({
    required this.email,
    required this.teamSlug,
    required this.onMessage,
    this.msgrBaseUrl = 'https://dev.msgr.no',
    this.pollInterval = const Duration(seconds: 2),
  });

  final String email;
  final String teamSlug;
  final String msgrBaseUrl;
  final Duration pollInterval;
  final Future<String?> Function(BotMessage message) onMessage;

  String? accountId;
  String? profileId;
  String? teamProfileId;
  final Map<String, String> channelNames = {};
  final Set<String> _seenMessageIds = {};
  final _client = http.Client();

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    if (accountId != null) 'X-Account-Id': accountId!,
    if (profileId != null) 'X-Profile-Id': profileId!,
  };

  /// Authenticate, join team, discover channels, start polling.
  Future<void> start() async {
    await _authenticate();
    await _joinTeam();
    await _discoverChannels();
    _startPolling();
  }

  Future<void> _authenticate() async {
    // Step 1: Request OTP challenge
    final challengeRes = await _client.post(
      Uri.parse('$msgrBaseUrl/api/v1/auth/challenge'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'channel': 'email', 'identifier': email}),
    );

    if (challengeRes.statusCode < 200 || challengeRes.statusCode >= 300) {
      throw MsgrBotException('Challenge failed (${challengeRes.statusCode}): ${challengeRes.body}');
    }

    final challengeData = jsonDecode(challengeRes.body) as Map<String, dynamic>;
    final challengeId = challengeData['id'] as String;
    final debugCode = challengeData['debug_code'] as String?;

    if (debugCode == null) {
      throw MsgrBotException('No debug_code in response — is EXPOSE_OTP_CODES=true set?');
    }

    print('[Bot] OTP challenge: $challengeId, code: $debugCode');

    // Step 2: Verify OTP
    final verifyRes = await _client.post(
      Uri.parse('$msgrBaseUrl/api/v1/auth/verify'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'challenge_id': challengeId, 'code': debugCode}),
    );

    if (verifyRes.statusCode < 200 || verifyRes.statusCode >= 300) {
      throw MsgrBotException('Verify failed (${verifyRes.statusCode}): ${verifyRes.body}');
    }

    final verifyData = jsonDecode(verifyRes.body) as Map<String, dynamic>;
    final account = verifyData['account'] as Map<String, dynamic>? ?? {};
    accountId = account['id'] as String?;
    profileId = verifyData['profile_id'] as String?;

    if (accountId == null || profileId == null) {
      throw MsgrBotException('No account/profile in verify response');
    }

    print('[Bot] Authenticated: account=$accountId, profile=$profileId');
  }

  Future<void> _joinTeam() async {
    // Try to join the team (idempotent — returns 201 or error if already member)
    final joinRes = await _client.post(
      Uri.parse('$msgrBaseUrl/api/teams/$teamSlug/join'),
      headers: _headers,
    );

    if (joinRes.statusCode == 201) {
      final data = jsonDecode(joinRes.body) as Map<String, dynamic>;
      final joinData = data['data'] as Map<String, dynamic>? ?? data;
      teamProfileId = joinData['profile_id'] as String?;
      print('[Bot] Joined team "$teamSlug", teamProfile=$teamProfileId');
    } else {
      print('[Bot] Join returned ${joinRes.statusCode}, fetching profile from team members...');
    }

    // Always try to find our team profile from the profiles list
    if (teamProfileId == null) {
      await _resolveTeamProfile();
    }
  }

  Future<void> _resolveTeamProfile() async {
    final res = await _client.get(
      Uri.parse('$msgrBaseUrl/api/teams/$teamSlug/profiles'),
      headers: _headers,
    );
    if (res.statusCode != 200) return;

    final data = jsonDecode(res.body);
    final profiles = (data is Map && data.containsKey('data'))
        ? data['data'] as List
        : data is List ? data : [];

    // Find our profile by matching account_id
    for (final p in profiles) {
      final pAccountId = p['account_id']?.toString();
      if (pAccountId == accountId) {
        teamProfileId = p['id']?.toString();
        print('[Bot] Resolved team profile: $teamProfileId');
        return;
      }
    }
    print('[Bot] Warning: could not find own team profile');
  }

  Future<void> _discoverChannels() async {
    final res = await _client.get(
      Uri.parse('$msgrBaseUrl/api/teams/$teamSlug/channels'),
      headers: _headers,
    );

    if (res.statusCode != 200) {
      print('[Bot] Could not fetch channels (${res.statusCode}): ${res.body}');
      return;
    }

    final data = jsonDecode(res.body);
    final channels = (data is Map && data.containsKey('data'))
        ? data['data'] as List
        : data is List ? data : [];

    channelNames.clear();
    for (final ch in channels) {
      final id = ch['id']?.toString() ?? '';
      final name = ch['name']?.toString() ?? ch['slug']?.toString() ?? '';
      if (id.isNotEmpty) channelNames[id] = name;
    }

    print('[Bot] Found ${channelNames.length} channels: ${channelNames.values.join(", ")}');

    // Seed seen messages so we don't reply to old ones
    for (final channelId in channelNames.keys) {
      await _indexExistingMessages(channelId);
    }
  }

  Future<void> _indexExistingMessages(String channelId) async {
    final res = await _client.get(
      Uri.parse('$msgrBaseUrl/api/teams/$teamSlug/channels/$channelId/messages?limit=50'),
      headers: _headers,
    );
    if (res.statusCode != 200) return;

    final data = jsonDecode(res.body);
    final messages = (data is Map && data.containsKey('data'))
        ? data['data'] as List
        : data is List ? data : [];

    for (final m in messages) {
      final id = m['id']?.toString();
      if (id != null) _seenMessageIds.add(id);
    }
    print('[Bot] Indexed ${messages.length} existing messages in #${channelNames[channelId]}');
  }

  void _startPolling() {
    print('[Bot] Polling every ${pollInterval.inSeconds}s...');
    Timer.periodic(pollInterval, (_) => _poll());
  }

  Future<void> _poll() async {
    for (final channelId in channelNames.keys) {
      try {
        final res = await _client.get(
          Uri.parse('$msgrBaseUrl/api/teams/$teamSlug/channels/$channelId/messages?limit=10'),
          headers: _headers,
        );
        if (res.statusCode != 200) continue;

        final data = jsonDecode(res.body);
        final messages = (data is Map && data.containsKey('data'))
            ? data['data'] as List
            : data is List ? data : [];

        for (final m in messages) {
          final id = m['id']?.toString() ?? '';
          if (id.isEmpty || _seenMessageIds.contains(id)) continue;
          _seenMessageIds.add(id);

          // Extract sender info (backend uses 'sender_profile' key)
          final sender = m['sender_profile'] as Map<String, dynamic>? ??
              m['sender'] as Map<String, dynamic>? ?? {};
          final senderProfileId = m['sender_profile_id']?.toString() ??
              sender['id']?.toString() ?? '';
          final senderName = sender['display_name']?.toString() ??
              sender['name']?.toString() ?? 'Ukjent';

          // Skip own messages
          if (senderProfileId == teamProfileId || senderProfileId == profileId) continue;

          // Extract content
          final rawContent = m['content'];
          final content = rawContent is Map
              ? (rawContent['text']?.toString() ?? rawContent.toString())
              : rawContent?.toString() ?? '';

          if (content.isEmpty) continue;

          print('[Bot] #${channelNames[channelId]}: $senderName: $content');

          final botMessage = BotMessage(
            channelId: channelId,
            channelName: channelNames[channelId] ?? '',
            senderName: senderName,
            senderProfileId: senderProfileId,
            content: content,
            messageId: id,
            timestamp: DateTime.tryParse(m['inserted_at']?.toString() ?? '') ?? DateTime.now(),
          );

          final reply = await onMessage(botMessage);
          if (reply != null && reply.isNotEmpty) {
            await sendMessage(channelId, reply);
          }
        }
      } catch (e, stack) {
        print('[Bot] Poll error: $e');
        print('[Bot] Stack: $stack');
      }
    }
  }

  Future<void> sendMessage(String channelId, String text) async {
    final res = await _client.post(
      Uri.parse('$msgrBaseUrl/api/teams/$teamSlug/channels/$channelId/messages'),
      headers: _headers,
      body: jsonEncode({'content': {'text': text}}),
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      print('[Bot] Failed to send message (${res.statusCode}): ${res.body}');
    } else {
      // Mark our own message as seen
      final data = jsonDecode(res.body);
      final msgData = data is Map && data.containsKey('data') ? data['data'] : data;
      final id = msgData is Map ? msgData['id']?.toString() : null;
      if (id != null) _seenMessageIds.add(id);
    }
  }
}

class BotMessage {
  const BotMessage({
    required this.channelId,
    required this.channelName,
    required this.senderName,
    required this.senderProfileId,
    required this.content,
    required this.messageId,
    required this.timestamp,
  });

  final String channelId;
  final String channelName;
  final String senderName;
  final String senderProfileId;
  final String content;
  final String messageId;
  final DateTime timestamp;
}

class MsgrBotException implements Exception {
  const MsgrBotException(this.message);
  final String message;
  @override
  String toString() => 'MsgrBotException: $message';
}
