import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

/// A message received by the bot.
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

/// Generic Msgr bot that authenticates, joins a team, and polls for messages.
class MsgrBot {
  MsgrBot({
    required this.email,
    required this.teamSlug,
    required this.onMessage,
    this.msgrBaseUrl = 'https://dev.msgr.no',
  });

  final String email;
  final String teamSlug;
  final String msgrBaseUrl;

  /// Called when a new message arrives. Return a string to reply, or null to skip.
  final Future<String?> Function(BotMessage message) onMessage;

  String? accountId;
  String? profileId;
  String? teamProfileId;
  String? _authToken;
  Map<String, String> channelNames = {};
  final Set<String> _seenMessageIds = {};
  Timer? _pollTimer;

  Map<String, String> get _authHeaders => {
        'Content-Type': 'application/json',
        if (_authToken != null) 'Authorization': 'Bearer $_authToken',
      };

  /// Authenticate, join team, discover channels, and start polling.
  Future<void> start() async {
    print('[Kåre] Kobler til $msgrBaseUrl som $email ...');

    // Step 1: Authenticate
    await _authenticate();
    print('[Kåre] Autentisert! accountId=$accountId');

    // Step 2: Get team profile
    await _joinTeam();
    print('[Kåre] Team-profil klar: teamProfileId=$teamProfileId');

    // Step 3: Discover channels
    await _discoverChannels();
    print('[Kåre] Fant ${channelNames.length} kanaler: ${channelNames.values.join(", ")}');

    // Step 4: Start polling
    print('[Kåre] Starter polling for meldinger (hvert 2. sekund)...');
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) => _poll());
  }

  /// Stop polling.
  void stop() {
    _pollTimer?.cancel();
    _pollTimer = null;
    print('[Kåre] Stoppet.');
  }

  /// Send a message to a channel.
  Future<void> sendMessage(String channelId, String text) async {
    final uri = Uri.parse('$msgrBaseUrl/api/v1/channels/$channelId/messages');
    final response = await http.post(
      uri,
      headers: _authHeaders,
      body: jsonEncode({'content': text}),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      print('[Kåre] Feil ved sending av melding (${response.statusCode}): ${response.body}');
    }
  }

  Future<void> _authenticate() async {
    // Request magic link / passwordless auth
    final loginUri = Uri.parse('$msgrBaseUrl/api/v1/auth/login');
    final loginResponse = await http.post(
      loginUri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email}),
    );

    if (loginResponse.statusCode != 200) {
      throw MsgrBotException(
        'Authentication failed (${loginResponse.statusCode}): ${loginResponse.body}',
      );
    }

    final loginJson = jsonDecode(loginResponse.body) as Map<String, dynamic>;
    _authToken = loginJson['token'] as String?;
    accountId = loginJson['account_id'] as String?;

    if (_authToken == null) {
      throw MsgrBotException(
        'No auth token in response. Body: ${loginResponse.body}',
      );
    }
  }

  Future<void> _joinTeam() async {
    final uri = Uri.parse('$msgrBaseUrl/api/v1/teams/$teamSlug/profile');
    final response = await http.get(uri, headers: _authHeaders);

    if (response.statusCode != 200) {
      throw MsgrBotException(
        'Failed to get team profile (${response.statusCode}): ${response.body}',
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    profileId = json['profile_id'] as String?;
    teamProfileId = json['team_profile_id'] as String? ?? json['id'] as String?;
  }

  Future<void> _discoverChannels() async {
    final uri = Uri.parse('$msgrBaseUrl/api/v1/teams/$teamSlug/channels');
    final response = await http.get(uri, headers: _authHeaders);

    if (response.statusCode != 200) {
      print('[Kåre] Kunne ikke hente kanaler (${response.statusCode})');
      return;
    }

    final json = jsonDecode(response.body) as List<dynamic>;
    for (final channel in json) {
      final ch = channel as Map<String, dynamic>;
      final id = ch['id'] as String;
      final name = ch['name'] as String? ?? 'unnamed';
      channelNames[id] = name;
    }
  }

  Future<void> _poll() async {
    try {
      for (final channelId in channelNames.keys) {
        await _pollChannel(channelId);
      }
    } catch (e) {
      print('[Kåre] Poll-feil: $e');
    }
  }

  Future<void> _pollChannel(String channelId) async {
    final uri = Uri.parse(
      '$msgrBaseUrl/api/v1/channels/$channelId/messages?limit=10',
    );
    final response = await http.get(uri, headers: _authHeaders);

    if (response.statusCode != 200) return;

    final messages = jsonDecode(response.body) as List<dynamic>;

    for (final msg in messages) {
      final m = msg as Map<String, dynamic>;
      final messageId = m['id'] as String;

      // Skip already-seen messages
      if (_seenMessageIds.contains(messageId)) continue;
      _seenMessageIds.add(messageId);

      final senderProfileId = m['sender_profile_id'] as String? ??
          m['profile_id'] as String? ??
          '';

      // Skip own messages
      if (senderProfileId == teamProfileId) continue;

      final content = m['content'] as String? ?? '';
      if (content.isEmpty) continue;

      final botMessage = BotMessage(
        channelId: channelId,
        channelName: channelNames[channelId] ?? 'unknown',
        senderName: m['sender_name'] as String? ??
            m['display_name'] as String? ??
            'unknown',
        senderProfileId: senderProfileId,
        content: content,
        messageId: messageId,
        timestamp: DateTime.tryParse(m['inserted_at'] as String? ?? '') ??
            DateTime.now(),
      );

      print(
        '[Kåre] #${botMessage.channelName} <${botMessage.senderName}>: ${botMessage.content}',
      );

      final reply = await onMessage(botMessage);
      if (reply != null && reply.isNotEmpty) {
        print('[Kåre] → $reply');
        await sendMessage(channelId, reply);
      }
    }
  }
}

class MsgrBotException implements Exception {
  MsgrBotException(this.message);
  final String message;

  @override
  String toString() => 'MsgrBotException: $message';
}
