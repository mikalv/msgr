import 'package:libmsgr/src/models/base.dart';
import 'package:libmsgr/src/utils/observable.dart';
import 'package:logging/logging.dart';

abstract class BaseRepository<T extends BaseModel> extends Observable<List<T>> {
  final Map<String, T> _localCache = {};
  final String teamName;

  late final Logger _log;

  Logger get log => _log;

  BaseRepository({required this.teamName}) {
    _log = Logger('${T.toString()}Repository');
  }

  @override
  String toString() => '${T.toString()}Repository{teamName: $teamName}';

  void fillLocalCache(List<T> items) {
    for (var item in items) {
      _localCache[item.id] = item;
    }
    notifyListeners(items);
  }

  void addItem(T item) {
    _localCache[item.id] = item;
    notifyListeners(_localCache.values.toList());
  }

  void updateItem(T item) {
    _localCache[item.id] = item;
    notifyListeners(_localCache.values.toList());
  }

  void removeItem(String id) {
    _localCache.remove(id);
    notifyListeners(_localCache.values.toList());
  }

  T getOrElse(String id, T Function() orElse) {
    return _localCache[id] ?? orElse();
  }

  T? getOrErrorElse(String id, Function() orElse) {
    if (_localCache.containsKey(id)) {
      return _localCache[id];
    } else {
      orElse();
      return null;
    }
  }

  List<T> get items => _localCache.values.toList();

  T fetchByID(String id) {
    return _localCache[id]!;
  }
}
