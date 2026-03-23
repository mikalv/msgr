import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

/// A headless Msgr bot that authenticates via bot-token, joins a team, and polls for messages.
class MsgrBot {
  MsgrBot({
    required this.email,
    required this.teamSlug,
    required this.onMessage,
    required this.botSecret,
    this.msgrBaseUrl = 'https://dev.msgr.no',
    this.pollInterval = const Duration(seconds: 2),
  });

  final String email;
  final String teamSlug;
  final String botSecret;
  final String msgrBaseUrl;
  final Duration pollInterval;
  final Future<String?> Function(BotMessage message) onMessage;

  String? accountId;
  String? profileId;
  String? teamProfileId;
  String? _accessToken;
  String? _refreshToken;
  final Map<String, String> channelNames = {};
  final Set<String> _seenMessageIds = {};
  final _client = http.Client();

  Map<String, String> get _headers {
    final h = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (_accessToken != null) {
      h['Authorization'] = 'Bearer $_accessToken';
    } else {
      if (accountId != null) h['X-Account-Id'] = accountId!;
      if (profileId != null) h['X-Profile-Id'] = profileId!;
    }
    return h;
  }

  /// Authenticate, join team, discover channels, start polling.
  /// Auto-reconnects on failure with exponential backoff.
  Future<void> start() async {
    var retryDelay = const Duration(seconds: 3);
    const maxDelay = Duration(seconds: 60);

    while (true) {
      try {
        await _authenticate();
        await _joinTeam();
        await _discoverChannels();
        print('[Bot] Ready — polling for messages');
        await _pollLoop();
      } catch (e) {
        print('[Bot] Error: $e — reconnecting in ${retryDelay.inSeconds}s');
        await Future.delayed(retryDelay);
        retryDelay = Duration(seconds: (retryDelay.inSeconds * 2).clamp(3, maxDelay.inSeconds));
      }
    }
  }

  Future<void> _authenticate() async {
    // Authenticate via bot-token endpoint (pre-shared secret, no OTP)
    final res = await _client.post(
      Uri.parse('$msgrBaseUrl/api/v1/auth/bot-token'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'bot_secret': botSecret}),
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw MsgrBotException('Bot auth failed (${res.statusCode}): ${res.body}');
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final account = data['account'] as Map<String, dynamic>? ?? {};
    accountId = account['id'] as String?;
    profileId = data['profile_id'] as String?;

    _accessToken = data['access_token'] as String?;
    _refreshToken = data['refresh_token'] as String?;

    if (accountId == null || profileId == null) {
      throw MsgrBotException('No account/profile in bot-token response');
    }

    print('[Bot] Authenticated: account=$accountId, profile=$profileId, jwt=${_accessToken != null ? "yes" : "no"}');
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

  /// Runs the poll loop forever. Throws on persistent HTTP errors to trigger reconnect.
  Future<void> _pollLoop() async {
    var consecutiveErrors = 0;
    while (true) {
      try {
        await _poll();
        consecutiveErrors = 0;
      } catch (e) {
        consecutiveErrors++;
        print('[Bot] Poll error ($consecutiveErrors): $e');
        if (consecutiveErrors >= 5) {
          throw MsgrBotException('Too many consecutive poll errors: $e');
        }
      }
      await Future.delayed(pollInterval);
    }
  }

  Future<void> _refreshAccessToken() async {
    if (_refreshToken == null) {
      print('[Bot] No refresh token — re-authenticating');
      await _authenticate();
      return;
    }
    try {
      final res = await _client.post(
        Uri.parse('$msgrBaseUrl/api/v1/auth/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh_token': _refreshToken}),
      );
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        _accessToken = data['access_token'] as String?;
        print('[Bot] Token refreshed');
      } else {
        print('[Bot] Refresh failed (${res.statusCode}) — re-authenticating');
        await _authenticate();
      }
    } catch (e) {
      print('[Bot] Refresh error: $e — re-authenticating');
      await _authenticate();
    }
  }

  Future<void> _poll() async {
    for (final channelId in channelNames.keys) {
      try {
        final res = await _client.get(
          Uri.parse('$msgrBaseUrl/api/teams/$teamSlug/channels/$channelId/messages?limit=10'),
          headers: _headers,
        );
        if (res.statusCode == 401) {
          await _refreshAccessToken();
          continue;
        }
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

          await _setTyping(channelId, true);
          final reply = await onMessage(botMessage);
          await _setTyping(channelId, false);
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

  Future<void> _setTyping(String channelId, bool typing) async {
    try {
      await _client.post(
        Uri.parse('$msgrBaseUrl/api/teams/$teamSlug/channels/$channelId/typing'),
        headers: _headers,
        body: jsonEncode({'typing': typing}),
      );
    } catch (_) {
      // Best effort — don't fail message flow for typing indicator
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
