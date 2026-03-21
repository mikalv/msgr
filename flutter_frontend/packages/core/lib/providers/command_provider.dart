import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:core/features/chat/widgets/chat_composer.dart';
import 'package:core/providers/msgr_client_provider.dart';
import 'package:core/providers/team_list_provider.dart';

/// Fetches the slash commands available for the currently selected team
/// from the server API. Falls back to an empty list if no team is selected.
final slashCommandsProvider = FutureProvider<List<SlashCommand>>((ref) async {
  final team = ref.watch(selectedTeamProvider);
  if (team == null) return [];

  final api = ref.read(msgrApiProvider);
  try {
    final data = await api.getCommands(team.slug);
    return data.map((cmd) {
      final name = cmd['name']?.toString() ?? '';
      final description = cmd['description']?.toString() ?? '';
      return SlashCommand('/$name', description);
    }).toList();
  } catch (_) {
    // If the API call fails (e.g. endpoint not deployed yet),
    // return empty list so the UI still works.
    return [];
  }
});
