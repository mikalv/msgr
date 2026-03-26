import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'team_list_provider.dart';

/// Manages per-team favorite channel/DM IDs, persisted to SharedPreferences.
class FavoritesNotifier extends StateNotifier<Set<String>> {
  FavoritesNotifier(this._teamSlug) : super({}) {
    _load();
  }

  final String _teamSlug;
  static const _prefix = 'msgr_favorites_';

  String get _key => '$_prefix$_teamSlug';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw != null) {
      try {
        final list = (jsonDecode(raw) as List).cast<String>();
        state = Set<String>.from(list);
      } catch (_) {}
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString(_key, jsonEncode(state.toList()));
  }

  bool isFavorite(String id) => state.contains(id);

  Future<void> toggle(String id) async {
    final updated = Set<String>.from(state);
    if (updated.contains(id)) {
      updated.remove(id);
    } else {
      updated.add(id);
    }
    state = updated;
    _save();
  }
}

final favoritesProvider =
    StateNotifierProvider<FavoritesNotifier, Set<String>>((ref) {
  final team = ref.watch(selectedTeamProvider);
  return FavoritesNotifier(team?.slug ?? '_none');
});
