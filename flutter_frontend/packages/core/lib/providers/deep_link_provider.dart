import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import 'channel_list_provider.dart';
import 'team_list_provider.dart';

final _log = Logger('DeepLink');

/// Parsed deep link from a msgr:// URI.
///
/// Format: `msgr://team-slug/channel-slug[/message-id]`
class MsgrDeepLink {
  const MsgrDeepLink({
    required this.teamSlug,
    this.channelSlug,
    this.messageId,
  });

  final String teamSlug;
  final String? channelSlug;
  final String? messageId;

  /// Parse a URI string into a deep link.
  /// Returns null if the URI is not a valid msgr:// deep link.
  static MsgrDeepLink? parse(String uriString) {
    try {
      final uri = Uri.parse(uriString);
      if (uri.scheme != 'msgr') return null;

      // msgr://team-slug/channel-slug/message-id
      // host = team-slug, pathSegments = [channel-slug, message-id?]
      final teamSlug = uri.host;
      if (teamSlug.isEmpty) return null;

      final segments = uri.pathSegments;
      final channelSlug = segments.isNotEmpty ? segments[0] : null;
      final messageId = segments.length > 1 ? segments[1] : null;

      return MsgrDeepLink(
        teamSlug: teamSlug,
        channelSlug: channelSlug,
        messageId: messageId,
      );
    } catch (_) {
      return null;
    }
  }

  /// Build a msgr:// URI string.
  String toUri() {
    var uri = 'msgr://$teamSlug';
    if (channelSlug != null) uri += '/$channelSlug';
    if (messageId != null) uri += '/$messageId';
    return uri;
  }
}

/// Navigate to a deep link by selecting the team and channel.
Future<void> handleDeepLink(Ref ref, MsgrDeepLink link) async {
  _log.info('Handling deep link: ${link.toUri()}');

  // Select team
  final teams = ref.read(teamsProvider);
  final team = teams.where((t) => t.slug == link.teamSlug).firstOrNull;
  if (team == null) {
    _log.warning('Team not found: ${link.teamSlug}');
    return;
  }
  ref.read(selectedTeamProvider.notifier).select(team);

  // Wait for channels to load (retry a few times)
  if (link.channelSlug != null) {
    for (var i = 0; i < 10; i++) {
      await Future.delayed(const Duration(milliseconds: 300));
      final channels = ref.read(channelListProvider).channels;
      final channel = channels.where((c) => c.slug == link.channelSlug || c.id == link.channelSlug).firstOrNull;
      if (channel != null) {
        ref.read(selectedChannelProvider.notifier).select(channel);
        _log.info('Navigated to #${channel.name}');
        return;
      }
    }
    _log.warning('Channel not found after retries: ${link.channelSlug}');
  }
}

/// Provider that listens for incoming msgr:// deep links via app_links.
/// Initialize by reading this provider after login.
final deepLinkListenerProvider = Provider<void>((ref) {
  if (kIsWeb) return; // Web handles URLs via path, not app_links

  final appLinks = AppLinks();

  // Handle link that opened the app (cold start)
  appLinks.getInitialLink().then((uri) {
    if (uri != null) {
      final link = MsgrDeepLink.parse(uri.toString());
      if (link != null) handleDeepLink(ref, link);
    }
  });

  // Handle links while app is running (warm start)
  final sub = appLinks.uriLinkStream.listen((uri) {
    final link = MsgrDeepLink.parse(uri.toString());
    if (link != null) handleDeepLink(ref, link);
  });

  ref.onDispose(() => sub.cancel());
});
