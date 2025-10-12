import 'package:flutter/foundation.dart';
import 'package:messngr/features/bridges/models/bridge_catalog_entry.dart';
import 'package:messngr/services/api/bridge_api.dart';
import 'package:messngr/services/api/chat_api.dart';

/// Holds catalog state for bridge connectors, including loading and filter
/// helpers.
class BridgeCatalogController extends ChangeNotifier {
  BridgeCatalogController({
    required AccountIdentity identity,
    BridgeApi? api,
  })  : _identity = identity,
        _api = api ?? BridgeApi();

  final AccountIdentity _identity;
  final BridgeApi _api;

  bool _loading = false;
  Object? _error;
  List<BridgeCatalogEntry> _entries = const [];
  String _filter = 'available';

  bool get isLoading => _loading;
  Object? get error => _error;
  String get filter => _filter;
  List<BridgeCatalogEntry> get entries => _entries;

  List<BridgeCatalogEntry> get visibleEntries {
    switch (_filter) {
      case 'all':
        return _entries;
      case 'coming_soon':
        return _entries.where((entry) => entry.isComingSoon).toList();
      case 'linked':
        return _entries
            .where((entry) => entry.auth['status']?.toString() == 'linked')
            .toList();
      case 'available':
      default:
        return _entries.where((entry) => entry.isAvailable).toList();
    }
  }

  Future<void> load() async {
    if (_loading) return;
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final results = await _api.listCatalog(current: _identity);
      _entries = results;
    } catch (err) {
      _error = err;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void applyFilter(String next) {
    if (_filter == next) return;
    _filter = next;
    notifyListeners();
  }
}
